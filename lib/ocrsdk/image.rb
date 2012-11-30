class OCRSDK::Image < OCRSDK::AbstractEntity
  include OCRSDK::Verifiers::Language
  include OCRSDK::Verifiers::Format
  include OCRSDK::Verifiers::Profile

  def initialize(image_path, application_id=nil, password=nil)
    super(application_id, password)
    @image_path = image_path
  end

  def as_text(languages)
    xml_string = api_process_image @image_path, languages, :txt, :text_extraction

    OCRSDK::Promise.from_response xml_string, @application_id, @password
  end

  def as_text_sync(languages, wait_interval=OCRSDK::DEFAULT_POLL_TIME)
    as_text(languages).wait(wait_interval).result.force_encoding('utf-8')
  end

  def as_pdf(languages)
    xml_string = api_process_image @image_path, languages, :pdf, :document_conversion

    OCRSDK::Promise.from_response xml_string, @application_id, @password
  end

  def as_pdf_sync(languages, out_path=nil, wait_interval=OCRSDK::DEFAULT_POLL_TIME)
    result = as_pdf(languages).wait(wait_interval).result

    if out_path.nil?
      result
    else
      File.open(out_path, 'wb+') {|f| f.write result }
    end
  end

private

  # TODO handle 4xx and 5xx responses and errors, file not found error
  # http://ocrsdk.com/documentation/apireference/processImage/
  def api_process_image(image_path, languages, format=:txt, profile=:document_conversion)
    raise OCRSDK::UnsupportedInputFormat   unless supported_input_format? File.extname(image_path)[1..-1]
    raise OCRSDK::UnsupportedOutputFormat  unless supported_output_format? format
    raise OCRSDK::UnsupportedProfile       unless supported_profile? (profile)

    params = URI.encode_www_form(
              language: languages_to_s(languages).join(','),
              exportFormat: format_to_s(format), 
              profile: profile_to_s(profile))
    uri = URI.join @url, '/processImage', "?#{params}"

    RestClient.post uri.to_s, upload: { file: File.new(image_path, 'rb') }
  rescue RestClient::ExceptionWithResponse
    raise OCRSDK::NetworkError
  end
end