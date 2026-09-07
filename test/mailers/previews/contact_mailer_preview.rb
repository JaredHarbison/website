require "ostruct"

class ContactMailerPreview < ActionMailer::Preview
  def prospect_message
    event = OpenStruct.new(metadata: {
      "name" => "Taylor Recruiter", "email" => "taylor@example.com",
      "message" => "I enjoyed the case studies and would like to connect."
    })
    opportunity = OpenStruct.new(company: "Example Co", role_title: "Staff Engineer")
    ContactMailer.prospect_message(event, opportunity)
  end
end
