require "jwt"
require "octokit"

module Underway
  class Api
    # Returns a Sawyer::Resource or PORO from the GitHub REST API
    def self.invoke(route, headers: {}, method: :get)
      debug_octokit! if verbose_logging?

      Octokit.api_endpoint = Underway::Settings.config.raw["github_api_host"]

      if !headers[:authorization] && !headers["Authorization"]
        Octokit.bearer_token = generate_jwt
      end

      final_headers = {
        accept: "application/vnd.github.machine-man-preview+json",
        headers: headers
      }

      begin
        case method
        when :post then Octokit.post(route, final_headers)
        else Octokit.get(route, final_headers)
        end
      rescue Octokit::Error => e
        { error: e.to_s }
      end
    end

    def self.generate_jwt
      payload = {
        # Issued at time:
        iat: Time.now.to_i,
        # JWT expiration time (10 minute maximum)
        exp: Time.now.to_i + (10 * 60),
        # GitHub Apps identifier
        iss: Underway::Settings.config.app_issuer
      }

      JWT.encode(payload, Underway::Settings.config.private_key, "RS256")
    end

    def self.debug_octokit!
      stack = Faraday::RackBuilder.new do |builder|
        builder.use Octokit::Middleware::FollowRedirects
        builder.use Octokit::Response::RaiseError
        builder.use Octokit::Response::FeedParser
        builder.response :logger
        builder.adapter Faraday.default_adapter
      end
      Octokit.middleware = stack
    end

    def self.verbose_logging?
      !!Underway::Settings.config.verbose_logging
    end
  end
end
