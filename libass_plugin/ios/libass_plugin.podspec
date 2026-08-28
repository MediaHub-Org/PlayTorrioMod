Pod::Spec.new do |s|
  s.name             = 'libass_plugin'
  s.version          = '1.0.0'
  s.summary          = 'Local wrapper plugin to bundle libass framework for iOS builds.'
  s.description      = <<-DESC
Local wrapper plugin to bundle libass (ass.framework) for iOS builds automatically via CocoaPods.
                       DESC
  s.homepage         = 'https://github.com/ayman708-UX/PlayTorrioV3'
  s.license          = { :type => 'MIT' }
  s.author           = { 'PlayTorrio' => 'dev@playtorrio.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'

  # Embed and link ass.framework into the target application
  s.vendored_frameworks = 'ass.framework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
