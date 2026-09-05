class ApprovedResume
  def self.path
    configured = ENV["APPROVED_GENERIC_RESUME_PATH"].presence
    configured && Rails.root.join(configured).to_s
  end

  def self.available?
    path.present? && File.file?(path)
  end

  def self.filename
    available? ? File.basename(path) : "Not approved"
  end

  def self.status
    { available: available?, filename: filename, updated_at: (File.mtime(path) if available?) }
  end
end
