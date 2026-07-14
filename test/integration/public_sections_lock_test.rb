require "test_helper"

class PublicSectionsLockTest < ActionDispatch::IntegrationTest
  test "home renders while public sections are locked" do
    with_public_sections_enabled(false) do
      get root_path
    end

    assert_response :success
    assert_select "h1", "Software Engineer"
  end

  test "navigation renders when public sections are enabled" do
    with_public_sections_enabled do
      get root_path
    end

    assert_response :success
    assert_select ".desktop-navigation nav[aria-label='Primary navigation']", 1
    assert_select ".desktop-navigation a", text: "About"
    assert_select ".desktop-navigation summary", text: /Case Studies/
    assert_select ".desktop-navigation summary", text: /Writing/
    assert_select ".desktop-navigation a", text: "Contact"
    assert_select ".desktop-navigation a.explorer__link--child", minimum: 5
    assert_select "#mobile-navigation[popover]", 1
    assert_select "button[popovertarget='mobile-navigation']", 2
    assert_select ".site-mark[aria-current='page']", "Jared Harbison"
    assert_select "a.site-mark", 0
    assert_select ".home-actions a", 2
    assert_select "link[rel='icon'][href='/jared-harbison-headshot-icon.png']", 1
    assert_select "link[rel='icon'][href='/jared-harbison-headshot.ico']", 1
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png']", 1
    assert_no_match(/site is being rebuilt/i, response.body)
  end

  test "active content section is expanded and current page is marked" do
    with_public_sections_enabled do
      get case_study_path("dogly-partner-applications")
    end

    assert_response :success
    assert_select ".desktop-navigation details.explorer__section[open]", 1
    assert_select ".desktop-navigation a[aria-current='page']", "Dogly Partner Applications"
  end

  test "content pages are inaccessible while public sections are locked" do
    with_public_sections_enabled(false) do
      get about_path
    end

    assert_response :not_found
  end

  test "case studies are inaccessible while public sections are locked" do
    with_public_sections_enabled(false) do
      get case_studies_path
    end

    assert_response :not_found
  end

  test "writing is inaccessible while public sections are locked" do
    with_public_sections_enabled(false) do
      get writings_path
    end

    assert_response :not_found
  end

  test "tags combine case studies and writing" do
    with_public_sections_enabled do
      get tag_path("rails")
    end

    assert_response :success
    assert_select "h1", "Rails"
    assert_select ".tag-results", 2
  end

  test "markdown-backed pages render when public sections are enabled" do
    with_public_sections_enabled do
      get about_path
    end

    assert_response :success
    assert_select "h1", "Jared Harbison"
    assert_select "img.about-portrait[width='480'][height='600']", 1
    assert_includes response.body, "Senior Software Engineer"
  end

  private

  def with_public_sections_enabled(enabled = true)
    previous = ENV["PUBLIC_SECTIONS_ENABLED"]
    ENV["PUBLIC_SECTIONS_ENABLED"] = enabled.to_s
    yield
  ensure
    ENV["PUBLIC_SECTIONS_ENABLED"] = previous
  end
end
