require 'set'
require 'rubygems'
require 'activesupport'
begin
  require 'action_controller'
rescue LoadError
  if ENV['ACTIONCONTROLLER_PATH'].nil?
    abort <<MSG
Please set the ACTIONCONTROLLER_PATH environment variable to the directory
containing the action_controller.rb file.
MSG
  else
    $LOAD_PATH.unshift ENV['ACTIONCONTROLLER_PATH']
    begin
      require 'action_controller'
    rescue LoadError
      abort "ActionController could not be found."
    end
  end
end


require 'test/unit'
require "#{File.dirname(__FILE__)}/../lib/ssl_requirement"

ActionController::Base.logger = nil
ActionController::Routing::Routes.reload rescue nil


class SslRequirementTest < ActionController::TestCase
  class SslRequirementController < ActionController::Base
    include SslRequirement
  
    ssl_required :a, :b
    ssl_allowed :c
  
    def a
      @flash_copy = {}.update flash
      @flashy = flash[:foo]
      render :inline => 'hello'
    end
  
    def b
      render :inline => 'hello'
    end
  
    def c
      render :inline => 'hello'
    end
  
    def d
      @flash_copy = {}.update flash
      @flashy = flash[:foo]
      render :inline => 'hello'
    end
  
    def set_flash
      flash[:foo] = "bar"
      render :inline => 'hello'
    end
  end
  
  tests SslRequirementController
  
  def setup
    SslRequirement.exclude_host = []
  end
  
  def test_redirect_to_https_preserves_flash
    get :set_flash
    get :b
    assert_response :redirect
    assert_equal "bar", flash[:foo]
  end
  
  def test_not_redirecting_to_https_does_not_preserve_the_flash
    get :set_flash
    get :d
    get :d
    assert_response :success
    assert_nil flash[:foo]
  end
  
  def test_redirect_to_http_preserves_flash
    get :set_flash
    @request.env['HTTPS'] = "on"
    get :d
    assert_response :redirect
    assert_equal "bar", flash[:foo]
  end
  
  def test_not_redirecting_to_http_does_not_preserve_the_flash
    get :set_flash
    @request.env['HTTPS'] = "on"
    get :a
    get :a
    assert_response :success
    assert_nil flash[:foo]
  end
  
  def test_required_without_ssl
    assert_not_equal "on", @request.env["HTTPS"]
    get :a
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
    get :b
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
  end
  
  def test_required_with_ssl
    @request.env['HTTPS'] = "on"
    get :a
    assert_response :success
    get :b
    assert_response :success
  end

  def test_disallowed_without_ssl
    assert_not_equal "on", @request.env["HTTPS"]
    get :d
    assert_response :success
  end
  
  def test_disallowed_with_ssl
    @request.env['HTTPS'] = "on"
    get :d
    assert_response :redirect
    assert_match %r{^http://}, @response.headers['Location']
  end

  def test_allowed_without_ssl
    assert_not_equal "on", @request.env["HTTPS"]
    get :c
    assert_response :success
  end

  def test_allowed_with_ssl
    @request.env['HTTPS'] = "on"
    get :c
    assert_response :success
  end

  def test_disable_ssl_check
    SslRequirement.disable_ssl_check = true

    assert_not_equal "on", @request.env["HTTPS"]
    get :a
    assert_response :success
    get :b
    assert_response :success
  ensure
    SslRequirement.disable_ssl_check = false
  end
  
  def test_exclude_host
    SslRequirement.exclude_host = ['test.host']
    @request.env['HTTPS'] = "on"
    get :d
    assert_response :success
  end
end

class SslAllActionsTest < ActionController::TestCase
  class SslAllActionsController < ActionController::Base
    include SslRequirement
  
    ssl_exceptions
    
    def a
      render :nothing => true
    end
  
  end
  
  tests SslAllActionsController
  
  def setup
    SslRequirement.exclude_host = []
  end
  
  def test_ssl_all_actions_without_ssl
    get :a
    
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
  end
end

class SslExceptionTest < ActionController::TestCase
  class SslExceptionController < ActionController::Base
    include SslRequirement
  
    ssl_required  :a
    ssl_exceptions :b
    ssl_allowed :d
    
    def a
      render :nothing => true
    end
  
    def b
      render :nothing => true
    end
  
    def c
      render :nothing => true
    end
  
    def d
      render :nothing => true
    end
  
    def set_flash
      flash[:foo] = "bar"
    end
  end
  
  tests SslExceptionController
  
  def setup
    SslRequirement.exclude_host = []
  end
  
  def test_ssl_exceptions_with_ssl
    @request.env['HTTPS'] = "on"
    get :a
    assert_response :success
    
    @request.env['HTTPS'] = "on"
    get :c
    assert_response :success
  end
  
  def test_ssl_exceptions_without_ssl
    get :a
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
    
    get :b
    assert_response :success
    
    get :c # c is not explicity in ssl_required, but it is not listed in ssl_exceptions
    assert_response :redirect
    assert_match %r{^https://}, @response.headers['Location']
  end
  
end