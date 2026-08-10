Pod::Spec.new do |s|
  s.name             = 'libass_plugin'
  s.version          = '1.0.0'
  s.summary          = 'Local plugin to bundle libass framework.'
  s.description      = <<-DESC
Local plugin to bundle libass framework for iOS builds automatically via CocoaPods.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Embed the framework so GitHub actions gets it automatically
  s.vendored_frameworks = 'ass.framework'
  
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
