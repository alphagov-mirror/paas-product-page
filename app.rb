require 'sinatra/base'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'sprockets'
require 'sinatra/sprockets-helpers'

require 'erubis'
require 'zendesk_api'

require './models/forms'

# App is the main Sinatra application
class App < Sinatra::Base

	set :sprockets, Sprockets::Environment.new
	set :title, 'GOV.UK Platform as a Service'
	set :erb, :escape_html => true

	# IMPORTANT: The app does not have CSRF protection enabled and if
	# you need sessions you should set that up appropriately using
	# Rack::Protection.
	set :sessions, false

	# Critical protection against Path Traversal.
	use Rack::Protection::PathTraversal

	# Protection to limit potential XSS attacks and effects.
	use Rack::Protection::ContentSecurityPolicy,
		:default_src => "none",
		:script_src => "'self' www.google-analytics.com",
		:style_src => "'self' 'unsafe-inline'",
		:img_src => "'self' prometheus-charts.leeporte.dev.cloudpipelineapps.digital www.google-analytics.com",
		:connect_src => "'self' www.google-analytics.com",
		:frame_src => "'self'",
		:font_src => "'self' data:",
		:object_src => "'self'",
		:media_src => "'self'"

	configure do
		sprockets.append_path File.join(root, 'assets', 'stylesheets', 'govuk_frontend_toolkit')
		sprockets.append_path File.join(root, 'assets', 'stylesheets', 'govuk_elements')
		sprockets.append_path File.join(root, 'assets', 'stylesheets', 'govuk_template')
		sprockets.append_path File.join(root, 'assets', 'stylesheets')
		sprockets.append_path File.join(root, 'assets', 'fonts')
		sprockets.append_path File.join(root, 'assets', 'js')
		sprockets.append_path File.join(root, 'assets')
		Sprockets::Helpers.configure do |config|
			config.debug = true if development?
			config.prefix = "/"
			config.environment = sprockets
		end
		register Sinatra::Reloader if development?
	end

	helpers Sinatra::ContentFor
	helpers Sprockets::Helpers
	helpers Forms::Helpers

	get '/?' do
		erb :index
	end

	get '/contact-us' do
		@errors = {}
		@form = Forms::Contact.new
		erb :'forms/contact-us'
	end

	post '/contact-us' do
		@errors = {}
		@form = Forms::Contact.new(params)

		if not @form.valid?
			@errors = @form.errors
			status 400
			erb :'forms/contact-us'
		else
			begin
				send_ticket @form
				@msg = "We’ll contact you in the next working day"
				erb :'forms/thanks'
			rescue => ex
				status 500
				@errors[:fatal] = [ex.to_s]
				erb :'forms/contact-us'
			end
		end
	end

	get '/signup' do
		@errors = {}
		@form = Forms::Signup.new({
			:person_is_manager => true,
			:invites => 3.times.map{ Forms::Invite.new({
				:person_email => '',
				:person_is_manager => false
			}) }
		})
		erb :'forms/signup'
	end

	post '/signup' do
		@errors = {}
		# Sanitise invites
		default_invite_params = {'0': {:person_email => '', :person_is_manager => false}}
		params[:invites] = (params[:invites] || default_invite_params).map{ |indexKey, invite|
			Forms::Invite.new(invite)
		}.reject{|invite| invite.person_email.empty? }

		# delete step
		params.delete(:step)

		@form = Forms::Signup.new(params)

		if not @form.valid?
			@errors = @form.errors
			status 400
			return erb :'forms/signup'
		else
			begin
				send_ticket @form
				@msg = "We’ll email you with your organisation account details in the next working day."
				erb :'forms/thanks'
			rescue => ex
				status 500
				@errors[:fatal] = [ex.to_s]
				erb :'forms/signup'
			end
		end
	end

	get '/support' do
		@errors = {}
		erb :'forms/support'
	end

	post '/support' do
		if params[:support_form].nil? or params[:support_form].empty?
			@errors = {support_form: "Please select an option"}
			status 400
			erb :'forms/support'
		else
			redirect("/support/#{params[:support_form]}", 302)
		end
	end

	# Get the model class form for the support page
	def get_support_form_class(name)
		case name
		when "something-wrong-with-service"
			Forms::SupportSomethingWrongWithService
		when "help-using-paas"
			Forms::SupportHelpUsingPaas
		when "find-out-more"
			Forms::SupportFindOutMore
		else
			nil
		end
	end

	get '/support/*' do
		form_name = params[:splat].first
		path = "forms/" + form_name
		if !/^[\/a-zA-Z0-9_-]+$/.match(form_name) or ! File.exist? "views/#{path}.erb"
            return not_found
		end

		form_class = get_support_form_class(form_name)
		if form_class.nil?
			return not_found
		end

		@form = form_class.new
		content_type 'text/html;charset=utf8'
		erb(path.to_sym)
	end

	post '/support/*' do
		form_name = params[:splat].first
		path = "forms/" + form_name
		if !/^[\/a-zA-Z0-9_-]+$/.match(form_name) or ! File.exist? "views/#{path}.erb"
            return not_found
		end

		form_class = get_support_form_class(form_name)
		if form_class.nil?
			return not_found
		end

		@errors = {}
		params.delete(:splat)
		@form = form_class.new(params)
		if not @form.valid?
			@errors = @form.errors
			status 400
			return erb(path.to_sym)
		else
			begin
				send_ticket @form
				submitted_path = path + '_submitted'
				if ! File.exist? "views/#{submitted_path}.erb"
					@msg = "We try to reply to all queries by the end of the next working day."
					erb :'forms/thanks'
				else
					erb(submitted_path.to_sym)
				end
			rescue => ex
				status 500
				@errors[:fatal] = [ex.to_s]
				erb(path.to_sym)
			end
		end
	end

	get '/*' do
		path = params[:splat].first

		# Check for a relevant erb template
		view_name = path.sub(/\.html$/, '')
		# Protected against directory traversal by Rack::Protection::PathTraversal
		# We also restrict view names to alphanumeric, dash and underscore characters.
		# These are definitively safe against being used for directory traversal/etc.
		if !/[^a-zA-Z0-9_-]/.match(view_name)
			# Check for an appropriately-named view
			if File.exist? "views/#{view_name}.erb"
				# Strip `.html` extension if present
				if path.match?(/\.html/)
					return redirect("/#{view_name}", 301)
				end

				# Render the view's erb template
				content_type 'text/html;charset=utf8'
				return erb(view_name.to_sym)
			end
		end

		# Check for an appropriately-named Sprocket asset
		res = settings.sprockets.call(env)
		return res if res && res[0] != 404

		# Return 404 Not Found
		not_found
	end

	not_found do
		content_type 'text/html;charset=utf8'
		erb :not_found
	end

	error do
		if settings.development?
			@error = env['sinatra.error']
		end
		content_type 'text/html;charset=utf8'
		erb :error
	end

	helpers do

		# create a zendesk client
		def zendesk
			ZendeskAPI::Client.new do |config|
				config.url = ENV['ZENDESK_URL']
				config.username = ENV['ZENDESK_USER']
				config.token = ENV['ZENDESK_TOKEN']
			end
		end

		def send_ticket(form)
			if ENV['FAKE_ZENDESK'].nil? or ENV['FAKE_ZENDESK'].empty?
				zendesk.tickets.create! form.to_zendesk_ticket
			else
				pp form.to_zendesk_ticket()
			end
		end

	end

end
