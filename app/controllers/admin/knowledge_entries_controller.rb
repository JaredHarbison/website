require "digest"

module Admin
  class KnowledgeEntriesController < BaseController
    before_action :set_knowledge_entry, only: :update

    def index
      @status = params[:status].presence || (KnowledgeEntry.where(approval_status: "needs_review").exists? ? "needs_review" : nil)
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
      @total_pages = [ 1, (@knowledge_count / 15.0).ceil ].max
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

    def new
      @knowledge_entry = KnowledgeEntry.new(approval_status: "candidate", visibility: "private", entry_type: "fact", source_type: "admin_manual")
    end

    def create
      attributes = knowledge_entry_params
      body = attributes[:body].to_s
      source_reference = attributes[:source_reference].to_s.strip
      entry = KnowledgeEntry.new(attributes.merge(
        approval_status: "candidate", visibility: "private", source_type: "admin_manual",
        source_reference: source_reference, source_fingerprint: Digest::SHA256.hexdigest([ source_reference, body ].join("\n")),
        metadata: { "evidence_classification" => "admin_created_candidate", "recruiter_evidence" => { "claims" => [], "capability_map" => {}, "approved_relationships" => [] }, "human_review" => { "status" => "REQUIRES_JARED_FACTUAL_REVIEW" } }
      ))
      if entry.save
        redirect_to admin_knowledge_entries_path, notice: "Candidate knowledge entry created privately. Add factual review before approval."
      else
        @knowledge_entry = entry
        flash.now[:alert] = entry.errors.full_messages.to_sentence
        render :new, status: :unprocessable_entity
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
        :title, :body, :short_body, :source_url, :public_url, :approval_status, :visibility, :reviewer_note, :source_reference, :entry_type
      )
    end
  end
end
