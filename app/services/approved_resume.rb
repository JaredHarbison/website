class ApprovedResume
  def self.path
    configured = ENV["APPROVED_GENERIC_RESUME_PATH"].presence
    configured && Rails.root.join(configured).to_s
  end

  def self.available?
    path.present? && File.file?(path)
  end

  def self.delivery_ready?
    available? && ENV["JARED_ISSUE_EMAIL"].present? && ENV["SMTP_USERNAME"].present? && ENV["SMTP_PASSWORD"].present?
  end

  def self.filename
    available? ? File.basename(path) : "Not approved"
  end

  def self.status
    { available: available?, delivery_ready: delivery_ready?, filename: filename, updated_at: (File.mtime(path) if available?) }
  end
end
