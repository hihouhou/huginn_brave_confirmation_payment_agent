module Agents
  class BraveConfirmationPaymentAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule '1d'

    description do
      <<-MD
      The Brave Confirmation PaymentAgent agent fetches confirmations from brave server and creates event.

      `changes_only` is used for only create an event for the change not all the payload.

      `wallet_id` is found at brave://rewards-internals/.

      `digest` is found at brave://rewards-internals/.

      `signature` is found at brave://rewards-internals/.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "month": "2020-07",
          "transactionCount": "120070",
          "balance": "6000.35"
        }
    MD

    def default_options
      {
        'wallet_id' => '',
        'digest' => '',
        'expected_receive_period_in_days' => '2',
        'signature' => '',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :wallet_id, type: :string
    form_configurable :digest, type: :string
    form_configurable :signature, type: :string
    form_configurable :changes_only, type: :boolean
    def validate_options
      unless options['wallet_id'].present?
        errors.add(:base, "wallet_id is a required field")
      end

      unless options['digest'].present?
        errors.add(:base, "digest is a required field")
      end

      unless options['signature'].present?
        errors.add(:base, "signature is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      memory['last_status'].to_i > 0

      return false if recent_error_logs?
      
      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      fetch
    end

    private

    def fetch

      uri = URI.parse("https://ads-serve.brave.com/v1/confirmation/payment/"+ interpolated['wallet_id'])
      request = Net::HTTP::Get.new(uri)
      request.content_type = "application/json"
      request["digest"] = "SHA-256=#{interpolated['digest']}"
      request["signature"] = "keyId=\"primary\",algorithm=\"ed25519\",headers=\"digest\",signature=\"#{interpolated['signature']}\""
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:59.0) Gecko/20100101 Firefox/59.0 Fuck You, it's not fair"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      
      log response.body

      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)

      unless options['wallet_id'].present?
        errors.add(:base, "wallet_id is a required field")
      end

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload.each do |payment|
              create_event payload: payment
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil,", ": null,")
            last_status = JSON.parse(last_status)
            payload.each do |payment|
              found = false
              last_status.each do |paymentbis|
                if payment == paymentbis
                    found = true
                end
              end
              if found == false
                  create_event payload: payment
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload.each_with_index.to_h
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
