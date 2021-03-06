require 'erb'
require 'tilt'

require 'rack/mime'

class MailView
  autoload :Mapper, 'mail_view/mapper'

  class << self
    def default_email_template_path
      File.expand_path('../mail_view/email.html.erb', __FILE__)
    end

    def default_index_template_path
      File.expand_path('../mail_view/index.html.erb', __FILE__)
    end

    def call(env)
      new.call(env)
    end
  end

  def call(env)
    @rack_env = env
    path_info = env["PATH_INFO"]

    if path_info == "" || path_info == "/"
      links = self.actions.map do |action|
        [action, "#{env["SCRIPT_NAME"]}/#{action}"]
      end

      ok index_template.render(Object.new, :links => links)
    elsif path_info =~ /([\w_]+)(\.\w+)?$/
      name   = $1
      format = $2 || ".html"

      if actions.include?(name)
        ok render_mail(name, send(name), format)
      else
        not_found
      end
    else
      not_found(true)
    end
  end

  protected
    # Mail views should be listed in order
    def actions
      (self.class.instance_methods - self.class.superclass.instance_methods).map(&:to_s).sort
    end

    def email_template
      Tilt.new(email_template_path)
    end

    def email_template_path
      self.class.default_email_template_path
    end

    def index_template
      Tilt.new(index_template_path)
    end

    def index_template_path
      self.class.default_index_template_path
    end

  private
    def ok(body)
      [200, {"Content-Type" => "text/html"}, [body]]
    end

    def not_found(pass = false)
      if pass
        [404, {"Content-Type" => "text/html", "X-Cascade" => "pass"}, ["Not Found"]]
      else
        [404, {"Content-Type" => "text/html"}, ["Not Found"]]
      end
    end

    def render_mail(name, mail, format = nil)
      body_part = mail

      if mail.multipart?
        content_type = Rack::Mime.mime_type(format)
        body_part = if mail.respond_to?(:all_parts)
                      mail.all_parts.find { |part| part.content_type.match(content_type) } || mail.parts.first
                    else
                      #NOTE: We have a problem previewing mails with attachments, seems mails with attachments
                      #      has nested multiparts(!?). Have not been able to reproduce it in a test
                      recursive_parts = mail.parts.map { |part| part.multipart? ? part.parts : part }.flatten
                      recursive_parts.find { |part| part.content_type.match(content_type) } || mail.parts.first
                    end
      end

      email_template.render(Object.new, :name => name, :mail => mail, :body_part => body_part)
    end
end
