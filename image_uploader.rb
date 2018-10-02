require "carrierwave"
require "carrierwave_direct"
require "carrierwave/storage/fog"

class ImageUploader < CarrierWave::Uploader::Base
	include CarrierWaveDirect::Uploader

  def extension_white_list
    %w(jpg jpeg gif png)
  end
end
