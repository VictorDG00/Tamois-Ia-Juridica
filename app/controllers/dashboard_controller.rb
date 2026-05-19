class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @recent_analyses = current_user.analyses.order(created_at: :desc).limit(10)
    @stats = {
      total: current_user.analyses.count,
      completed: current_user.analyses.where(status: "completed").count,
      high_risk: current_user.analyses.where(status: "completed")
                              .select { |a| a.legal_insights.any? { |i| i["risk_level"] == "high" } }
                              .count
    }
  end
end
