require './models/model'

module Forms
	VALID_EMAIL_REGEX = /.+@.+\..+/
	UNKNOWN_ERROR_MESSAGE = "Your request could not be submitted through this form. Please email govuk-paas-support@digital.cabinet-office.gov.uk directly."

	class GenericContact < Model
		MAX_FIELD_LEN = 2048
		MAX_MESSAGE_LEN = 50000

		field :person_name,                  String, :required => true, :min => 2, :max => MAX_FIELD_LEN, :label => 'Name'
		field :person_email,                 String, :required => true, :match => VALID_EMAIL_REGEX, :min => 5, :max => MAX_FIELD_LEN, :label => 'Email address'
		field :message,                      String, :required => true, :max => MAX_MESSAGE_LEN, :min => 1, :label => 'Message'

		def subject
			"[PaaS Support] #{Date.today.to_s} support request from website"
		end

		def rendered_message
			message_lines = []
			message_lines << "From: #{person_name}"
			message_lines << "Email: #{person_email}"

			extra_fields = self.class.fields
			extra_fields.delete(:person_name)
			extra_fields.delete(:person_email)
			extra_fields.delete(:message)

			message_lines += extra_fields.map {|k,v|
					"#{v[:label]}: #{self.values[k]}"
			}
			message_lines << ""
			message_lines << message

			message_lines.join("\n")
		end

		def to_zendesk_ticket()
			ticket = {}
			ticket[:subject] = subject
			ticket[:comment] = { body: rendered_message }
			ticket[:requester] = {
				email: person_email,
				name: person_name,
			}
			ticket[:tags] = [ 'govuk_paas_support', 'govuk_paas_product_page' ]
			ticket[:group_id] = ENV['ZENDESK_GROUP_ID'].to_i if ENV['ZENDESK_GROUP_ID']
			ticket
		end
	end

	class Contact < GenericContact
		field :department_name,              String, :required => true, :label => "Department name"
		field :service_name,                 String, :required => true, :label => "Service name"
	end

	class Invite < Model
		field :person_name,                  String, :label => 'Name'
		field :person_email,                 String, :match => VALID_EMAIL_REGEX, :label => 'Email address'
		field :person_is_manager,            Boolean
	end

	class Signup < GenericContact

    VALID_GOV_DOMAIN_REGEX = Regexp.union(
      # GOV.UK and nested subdomains
      /[^@]+@gov[.]uk$/,
      /[^@]+@[-.a-z0-9]+[.]gov[.]uk$/,

      # MoD and nested subdomains
      /[^@]+@mod[.]uk$/,
      /[^@]+@[-.a-z0-9]+[.]mod[.]uk$/,

      # Police and nested subdomains
      /[^@]+@police[.]uk$/,
      /[^@]+@[-.a-z0-9]+[.]police[.]uk$/,

      # NHS and nested subdomains
      /[^@]+@nhs[.]uk$/,
      /[^@]+@[-.a-z0-9]+[.]nhs[.]uk$/,
      /[^@]+@nhs[.]net$/,
      /[^@]+@[-.a-z0-9]+[.]nhs[.]net$/,
    )

		field :message,                      String, :required => false # Make message optional

		# Ensure the email is .gov.uk
		field :person_email,                 String, :required => true, :match => VALID_GOV_DOMAIN_REGEX, :min => 5, :label => 'Email address'

		field :person_is_manager,            Boolean
		field :department_name,              String, :required => true
		field :service_name,                 String, :required => true
		field :invite_users,                 Boolean
		field :invites,                      Array, :of => Invite

		def subject
			"[PaaS Support] #{Date.today.to_s} Registration Request"
		end

		def rendered_message
			msg = [
				"New organisation/account signup request from website",
				"",
				"From: #{person_name}",
				"Email: #{person_email} #{"(org manager)" if person_is_manager}",
				"Department: #{department_name}",
				"Team/Service: #{service_name}",
			].join("\n")
			if invite_users
				msg << ([
					"",
					"They would also like to invite:",
				] + invites.map{ |invite| " - #{invite.person_email} #{"(org manager)" if invite.person_is_manager}" }).join("\n")
			end
			msg
		end
	end

	class SupportSomethingWrongWithService < GenericContact
		field :organization_name,	String, :required => true, :label => 'Organisation name'
		field :severity,			String, :required => true, :label => 'Severity'

		def subject
			"[PaaS Support] #{Date.today.to_s} something wrong in #{organization_name} live service"
		end
	end

	class SupportHelpUsingPaas < GenericContact
		field :organization_name,	String, :required => false, :label => 'Organisation name'

		def subject
			"[PaaS Support] #{Date.today.to_s} request for help"
		end
	end

	class SupportFindOutMore < GenericContact
		field :organization_name,	String, :required => true, :label => 'Organisation name'

		def subject
			"[PaaS Support] #{Date.today.to_s} request for information"
		end
	end

	module Helpers

		# return comma seperated list of errors from validation if resourse has been validated
		def errors_for(record, field)
			return nil if !record.validated?
			errs = record.errors[field]
			return nil if !errs or errs.size == 0
			return errs.join(", ")
		end

		def input_for(record, name, **kwargs)
			field = record.class.fields[name]
			raise "#{record} has no field #{name}" if not field
			erb :"partials/_input", :locals => {
				name: name,
				label: kwargs[:label] || name.to_s.gsub(/_/,' '),
				hint: kwargs[:hint] || '',
				value: record.send(name),
				error: errors_for(record, name)
			}
		end

		def radio_for(record, name, **kwargs)
			field = record.class.fields[name]
			raise "#{record} has no field #{name}" if not field
			erb :"partials/_radio", :locals => {
				name: name,
				label: kwargs[:label] || name.to_s.gsub(/_/,' '),
				hint: kwargs[:hint] || '',
				value: record.send(name),
				error: errors_for(record, name),
				options: kwargs[:options] || [],
			}
		end

	end

end
