require "test_helper"

class DdnsSettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get ddns_settings_index_url
    assert_response :success
  end

  test "should get update" do
    get ddns_settings_update_url
    assert_response :success
  end

  test "should get toggle_service" do
    get ddns_settings_toggle_service_url
    assert_response :success
  end
end
