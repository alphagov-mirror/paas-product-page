require 'rack/test'
require 'capybara/rspec'
require 'net/http'
Capybara.app = Rack::Builder.parse_file("config.ru").first

RSpec.describe "Signup", :type => :feature do

	include Rack::Test::Methods

  it "should submit the form successfully with gov.uk email" do
		visit '/signup'
		fill_in('person_name', with: 'Jeff Jefferson')
		fill_in('person_email', with: 'jeff@test.gov.uk')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		find('input#person_is_manager-0.toggle-radio-note').set(true)
		click_button('signup-submit')
		all('.error-message').each do |err|
			expect(err.text).to be_empty, "Did not expect to see any validation errors but got: #{err.text}"
		end
		all('.error-summary .err').each do |err|
			expect(err.text).to be_empty, "Did not expect to see a summary of errors but got: #{err.text}"
		end
		expect(page.status_code).to eq(200)

		expect(WebMock).to have_requested(
			:post, "#{ENV['ZENDESK_URL']}/tickets"
		).once.with{|req|
			data = JSON.parse(req.body)
			expect(data).to include("ticket")
			expect(data["ticket"]).to include("subject")
			expect(data["ticket"]["subject"]).to match(/\[PaaS Support\] .* Registration Request/)
			expect(data["ticket"]).to include("requester" => {"email"=>"jeff@test.gov.uk", "name"=>"Jeff Jefferson"})
			expect(data["ticket"]).to include("group_id" => ENV['ZENDESK_GROUP_ID'].to_i)
			expect(data["ticket"]).to include("tags")
			expect(data["ticket"]["tags"]).to include("govuk_paas_support")
			expect(data["ticket"]["tags"]).to include("govuk_paas_product_page")

			expect(data["ticket"]).to include("comment")
			expect(data["ticket"]["comment"]).to include("body")
			expect(data["ticket"]["comment"]["body"]).to include("From: Jeff Jefferson")
			expect(data["ticket"]["comment"]["body"]).to include("Email: jeff@test.gov.uk")
			expect(data["ticket"]["comment"]["body"]).to include("Department: TestDept")
			expect(data["ticket"]["comment"]["body"]).to include("Team/Service: TestService")
			expect(data["ticket"]["comment"]["body"]).to include("They would also like to invite")
		}
	end

  %w(net uk).each do |tld|
    it "should submit the form successfully with an nhs.#{tld} email" do
      email = "jane@nhs.#{tld}"

      visit '/signup'
      fill_in('person_name', with: 'Jane Janedóttir')
      fill_in('person_email', with: email)
      fill_in('department_name', with: 'TestDept')
      fill_in('service_name', with: 'TestService')
      find('input#person_is_manager-0.toggle-radio-note').set(true)
      click_button('signup-submit')
      all('.error-message').each do |err|
        expect(err.text).to be_empty, "Did not expect to see any validation errors but got: #{err.text}"
      end
      all('.error-summary .err').each do |err|
        expect(err.text).to be_empty, "Did not expect to see a summary of errors but got: #{err.text}"
      end
      expect(page.status_code).to eq(200)

      expect(WebMock).to have_requested(
        :post, "#{ENV['ZENDESK_URL']}/tickets"
      ).once.with{|req|
        data = JSON.parse(req.body)
        expect(data).to include("ticket")
        expect(data["ticket"]).to include("subject")
        expect(data["ticket"]["subject"]).to match(/\[PaaS Support\] .* Registration Request/)
        expect(data["ticket"]).to include("requester" => {"email"=>email, "name"=>"Jane Janedóttir"})
        expect(data["ticket"]).to include("group_id" => ENV['ZENDESK_GROUP_ID'].to_i)
        expect(data["ticket"]).to include("tags")
        expect(data["ticket"]["tags"]).to include("govuk_paas_support")
        expect(data["ticket"]["tags"]).to include("govuk_paas_product_page")

        expect(data["ticket"]).to include("comment")
        expect(data["ticket"]["comment"]).to include("body")
        expect(data["ticket"]["comment"]["body"]).to include("From: Jane Janedóttir")
        expect(data["ticket"]["comment"]["body"]).to match(/Email: jane@nhs.(uk|net)/)
        expect(data["ticket"]["comment"]["body"]).to include("Email: #{email}")
        expect(data["ticket"]["comment"]["body"]).to include("Department: TestDept")
        expect(data["ticket"]["comment"]["body"]).to include("Team/Service: TestService")
        expect(data["ticket"]["comment"]["body"]).to include("They would also like to invite")
      }
    end
	end

	it "should require person_name field" do
		visit '/signup'
		fill_in('person_email', with: 'jeff@test.gov.uk')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		click_button('signup-submit')
		expect(page.first('.form-group--person_name .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

	it "should require person_email field" do
		visit '/signup'
		fill_in('person_name', with: 'jeff')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		click_button('signup-submit')
		expect(page.first('.form-group--person_email .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

	it "should require a valid email for person_email" do
		visit '/signup'
		fill_in('person_name', with: 'jeff')
		fill_in('person_email', with: 'not-an-email')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		click_button('signup-submit')
		expect(page.first('.form-group--person_email .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

  it "should require a .gov.uk or .nhs.net email for person_email" do
		visit '/signup'
		fill_in('person_name', with: 'jeff')
		fill_in('person_email', with: 'jeff@gmail.com')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		click_button('signup-submit')
		expect(page.first('.form-group--person_email .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

	it "should require department_name field" do
		visit '/signup'
		fill_in('person_name', with: 'jeff')
		fill_in('person_email', with: 'jeff@test.gov.uk')
		fill_in('service_name', with: 'TestService')
		click_button('signup-submit')
		expect(page.first('.form-group--department_name .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

	it "should require service_name field" do
		visit '/signup'
		fill_in('person_name', with: 'jeff')
		fill_in('person_email', with: 'jeff@test.gov.uk')
		fill_in('department_name', with: 'TestDept')
		click_button('signup-submit')
		expect(page.first('.form-group--service_name .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

	it "should require a valid email invitation email (if set)" do
		visit '/signup'
		fill_in('person_name', with: 'jeff')
		fill_in('person_email', with: 'jeff@x.gov.uk')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		fill_in('invites[1]person_email', with: 'not-an-email')
		click_button('signup-submit')
		expect(page.first('.form-group--invites .error-message').text).not_to be_empty
		expect(page.status_code).to eq(400)
	end

	it "should submit the form successfully when not an org manager" do
		visit '/signup'
		fill_in('person_name', with: 'Jeff Jefferson')
		fill_in('person_email', with: 'jeff@test.gov.uk')
		fill_in('department_name', with: 'TestDept')
		fill_in('service_name', with: 'TestService')
		find('input#person_is_manager-1.toggle-radio-note').set(true)
		click_button('signup-submit')
		all('.error-message').each do |err|
			expect(err.text).to be_empty, "Did not expect to see any validation errors but got: #{err.text}"
		end
		all('.error-summary .err').each do |err|
			expect(err.text).to be_empty, "Did not expect to see a summary of errors but got: #{err.text}"
		end
		expect(page.status_code).to eq(200)
	end

end
