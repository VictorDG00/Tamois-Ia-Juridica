class AnalysesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_analysis, only: %i[show]

  def index
    @analyses = current_user.analyses.order(created_at: :desc)
  end

  def new
    @analysis = Analysis.new
  end

  def create
    file = params[:analysis][:docx_file]
    mode = params[:analysis][:analysis_mode].presence_in(%w[fast deep]) || "fast"

    unless file
      flash[:alert] = "Por favor, envie um arquivo DOCX."
      return redirect_to new_analysis_path
    end

    unless file.content_type.in?(%w[
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/octet-stream
    ]) || file.original_filename.ends_with?(".docx")
      flash[:alert] = "O arquivo deve estar no formato DOCX."
      return redirect_to new_analysis_path
    end

    @analysis = current_user.analyses.build(
      filename: file.original_filename,
      analysis_mode: mode,
      status: "pending"
    )
    @analysis.docx_file.attach(file)

    if @analysis.save
      begin
        AnalysisService.new(@analysis).run
        redirect_to @analysis, notice: "Análise concluída com sucesso."
      rescue => e
        flash[:alert] = "Erro ao analisar o documento: #{e.message}"
        redirect_to new_analysis_path
      end
    else
      flash[:alert] = "Erro ao salvar o arquivo."
      redirect_to new_analysis_path
    end
  end

  def show
  end

  private

  def set_analysis
    @analysis = current_user.analyses.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to analyses_path, alert: "Análise não encontrada."
  end
end
