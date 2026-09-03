module Admin
  class KnowledgeEntriesController < BaseController
    before_action :set_knowledge_entry, only: :update

    def index
      @status = params[:status].presence
      @visibility = params[:visibility].presence
      @query = params[:q].to_s.strip
      @knowledge_entries = KnowledgeEntry.order(updated_at: :desc)
      @knowledge_entries = @knowledge_entries.where(approval_status: @status) if @status
      @knowledge_entries = @knowledge_entries.where(visibility: @visibility) if @visibility
      if @query.present?
        pattern = "%#{KnowledgeEntry.sanitize_sql_like(@query)}%"
        @knowledge_entries = @knowledge_entries.where("title LIKE :pattern OR body LIKE :pattern OR source_reference LIKE :pattern", pattern: pattern)
      end
      @knowledge_count = @knowledge_entries.count
      @page = [ params.fetch(:page, 1).to_i, 1 ].max
      @knowledge_entries = @knowledge_entries.limit(15).offset((@page - 1) * 15)
    end

    def update
      attributes = knowledge_entry_params
      attributes[:visibility] = "recruiter_visible" if attributes[:approval_status] == "approved" && attributes[:visibility].blank?
      attributes[:approved_at] = attributes[:approval_status] == "approved" ? Time.current : nil
      attributes[:reviewed_by] = current_admin_user.email

      if @knowledge_entry.update(attributes)
        redirect_to admin_knowledge_entries_path, notice: "Knowledge entry updated."
      else
        redirect_to admin_knowledge_entries_path, alert: @knowledge_entry.errors.full_messages.to_sentence
      end
    end

    private

    def set_knowledge_entry
      @knowledge_entry = KnowledgeEntry.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      admin_not_found
    end

    def knowledge_entry_params
      params.require(:knowledge_entry).permit(
        :title, :body, :short_body, :source_url, :public_url, :approval_status, :visibility, :reviewer_note
      )
    end
  end
end
