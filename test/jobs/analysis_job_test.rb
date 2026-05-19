require "test_helper"

class AnalysisJobTest < ActiveJob::TestCase
  def setup
    @user = create_user
    @analysis = create_analysis(user: @user, status: "pending")
  end

  test "enfileira o job corretamente" do
    assert_enqueued_with(job: AnalysisJob, args: [@analysis.id]) do
      AnalysisJob.perform_later(@analysis.id)
    end
  end

  test "não quebra quando análise não existe" do
    assert_nothing_raised do
      AnalysisJob.perform_now(999_999)
    end
  end
end
