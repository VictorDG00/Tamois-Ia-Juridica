ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    fixtures :all

    def create_user(name: "Test User", email: "test@example.com", password: "password123")
      User.create!(name: name, email: email, password: password, password_confirmation: password)
    end

    def create_analysis(user:, filename: "test.docx", status: "completed", mode: "fast")
      Analysis.create!(
        user: user,
        filename: filename,
        status: status,
        analysis_mode: mode,
        orthography_json: [].to_json,
        writing_suggestions_json: [].to_json,
        legal_insights_json: [].to_json
      )
    end
  end
end
