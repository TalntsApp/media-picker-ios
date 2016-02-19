Pod::Spec.new do |s|

  s.name          = "MediaPicker"
  s.version       = "0.0.1"
  s.summary       = "Control that allows you to pick assets from gallery"

  s.homepage      = "http://talnts.com"

  s.license       = "MIT"

  s.author        = { "Mikhail Stepkin, Ramotion Inc." => "mikhail.s@ramotion.com" }

  s.platform      = :ios, "8.0"

  s.source        = { :git => "https://github.com/TalntsApp/media-picker-ios.git", :tag => "0.0.1" }

  s.source_files  = "MediaPicker", "MediaPicker/**/*.{h,m,swift}"
  s.exclude_files = "Example", "Example/**/*.{h,m,swift}"

  s.public_header_files = "MediaPicker/MediaPicker.h"

  s.frameworks    = "Photos", "AVFoundation", "MediaPlayer"

  s.requires_arc  = true

  s.dependency "Runes"
  s.dependency "Argo"
  s.dependency 'Signals', '~> 2.3'
  s.dependency 'BABCropperView', '~> 0.4'

end
