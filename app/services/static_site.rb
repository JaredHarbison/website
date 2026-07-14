require "fileutils"
require "pathname"
require "uri"

module StaticSite
  class BuildError < StandardError; end

  class RouteSet
    def paths
      [
        "/",
        "/about",
        "/contact",
        "/case-studies",
        *case_studies.map { |entry| "/case-studies/#{entry.slug}" },
        "/writing",
        *articles.map { |entry| "/writing/#{entry.slug}" },
        "/tags",
        *tags.map { |tag| "/tags/#{tag.slug}" }
      ].uniq
    end

    private

    def case_studies
      ContentRepository.new(collection: "case_studies", model: CaseStudy).all
    end

    def articles
      ContentRepository.new(collection: "writing", model: Article).all
    end

    def tags
      TagCatalog.new.all
    end
  end

  class Builder
    DEFAULT_DOMAIN = "www.jaredharbison.com"

    attr_reader :domain, :output_path, :public_path, :routes

    def initialize(
      output_path: Rails.root.join("_site"),
      public_path: Rails.root.join("public"),
      routes: RouteSet.new,
      domain: ENV.fetch("SITE_DOMAIN", DEFAULT_DOMAIN)
    )
      @domain = domain
      @output_path = Pathname(output_path)
      @public_path = Pathname(public_path)
      @routes = routes
    end

    def build
      prepare_output
      copy_public_files
      render_routes
      write_pages_metadata
      output_path
    end

    private

    def prepare_output
      FileUtils.rm_rf(output_path)
      output_path.mkpath
    end

    def copy_public_files
      public_path.children.each do |source|
        FileUtils.cp_r(source, output_path.join(source.basename))
      end
    end

    def render_routes
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.host! domain
      session.https!

      routes.paths.each do |path|
        session.get(path)
        response = session.response

        unless (200..299).cover?(response.status)
          raise BuildError, "#{path} rendered with HTTP #{response.status}"
        end

        destination = destination_for(path)
        destination.dirname.mkpath
        destination.write(response.body)
      end
    end

    def destination_for(path)
      return output_path.join("index.html") if path == "/"

      output_path.join(path.delete_prefix("/"), "index.html")
    end

    def write_pages_metadata
      output_path.join(".nojekyll").write("")
      output_path.join("CNAME").write("#{domain}\n")
    end
  end

  class Validator
    ATTRIBUTE_PATTERN = /(?:href|src)=["'](?<reference>[^"']+)["']/
    EXTERNAL_SCHEMES = %w[data http https mailto tel].freeze
    LEGACY_MARKERS = [
      "You need to enable JavaScript to run this app",
      "/static/js/main.",
      "/static/css/main."
    ].freeze

    attr_reader :output_path, :routes

    def initialize(output_path: Rails.root.join("_site"), routes: RouteSet.new)
      @output_path = Pathname(output_path)
      @routes = routes
    end

    def validate!
      errors = []
      html_files = output_path.glob("**/*.html")

      errors << "no HTML files were generated" if html_files.empty?
      validate_expected_routes(errors)
      html_files.each { |file| validate_html(file, errors) }

      raise BuildError, errors.join("\n") if errors.any?

      true
    end

    private

    def validate_expected_routes(errors)
      routes.paths.each do |path|
        destination = path == "/" ? output_path.join("index.html") : output_path.join(path.delete_prefix("/"), "index.html")
        errors << "missing rendered route: #{path}" unless destination.file?
      end
    end

    def validate_html(file, errors)
      html = file.read

      LEGACY_MARKERS.each do |marker|
        errors << "#{relative(file)} contains legacy asset or markup: #{marker}" if html.include?(marker)
      end

      html.scan(ATTRIBUTE_PATTERN).flatten.each do |reference|
        validate_reference(file, reference, errors)
      end
    end

    def validate_reference(file, reference, errors)
      return if reference.empty? || reference.start_with?("#", "//")

      uri = URI.parse(reference)
      return if EXTERNAL_SCHEMES.include?(uri.scheme)

      path = uri.path
      return if path.blank?

      target = if path.start_with?("/")
        output_path.join(path.delete_prefix("/"))
      else
        file.dirname.join(path)
      end

      target = target.join("index.html") if target.extname.empty?
      errors << "#{relative(file)} references missing file: #{reference}" unless target.file?
    rescue URI::InvalidURIError
      errors << "#{relative(file)} contains an invalid URL: #{reference}"
    end

    def relative(file)
      file.relative_path_from(output_path)
    end
  end
end
