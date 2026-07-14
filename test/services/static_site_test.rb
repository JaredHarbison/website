require "test_helper"

class StaticSiteTest < ActiveSupport::TestCase
  test "route set includes every published collection entry and tag" do
    paths = StaticSite::RouteSet.new.paths

    assert_includes paths, "/"
    assert_includes paths, "/case-studies/dogly-product-design"
    assert_includes paths, "/writing/product-planning-and-scope"
    assert_includes paths, "/tags/product-engineering"
    assert_equal paths.uniq, paths
  end

  test "builder renders application routes without copying the legacy root" do
    Dir.mktmpdir do |directory|
      output_path = Pathname(directory).join("site")
      routes = Struct.new(:paths).new([ "/", "/about" ])

      StaticSite::Builder.new(output_path: output_path, routes: routes).build

      assert_file output_path.join("index.html")
      assert_file output_path.join("about/index.html")
      assert_file output_path.join(".nojekyll")
      assert_equal "www.jaredharbison.com\n", output_path.join("CNAME").read
      assert_no_match(/You need to enable JavaScript/, output_path.join("index.html").read)
    end
  end

  test "validator rejects missing internal references and legacy markup" do
    Dir.mktmpdir do |directory|
      output_path = Pathname(directory)
      output_path.join("index.html").write(<<~HTML)
        <p>You need to enable JavaScript to run this app.</p>
        <a href="/missing">Missing</a>
      HTML
      routes = Struct.new(:paths).new([ "/" ])

      error = assert_raises(StaticSite::BuildError) do
        StaticSite::Validator.new(output_path: output_path, routes: routes).validate!
      end

      assert_match(/legacy asset or markup/, error.message)
      assert_match(%r{missing file: /missing}, error.message)
    end
  end

  private

  def assert_file(path)
    assert_predicate path, :file?, "Expected #{path} to be a file"
  end
end
