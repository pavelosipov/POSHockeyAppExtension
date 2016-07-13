Pod::Spec.new do |s|
  
  s.name         = 'POSHockeyAppExtension'
  s.version      = '1.0.7'
  s.license      = 'MIT'
  s.summary      = 'Plugin to HockeyApp SDK for tracking events of a non-crash nature.'
  s.homepage     = 'https://github.com/pavelosipov/POSHockeyAppExtension'
  s.authors      = { 'Pavel Osipov' => 'posipov84@gmail.com' }
  s.source       = { :git => 'https://github.com/pavelosipov/POSHockeyAppExtension.git', :tag => '1.0.7' }
  s.requires_arc = true

  s.ios.deployment_target = '7.0'

  s.source_files = 'POSHockeyAppExtension/**/*.{h,m}'
  
  s.dependency 'HockeySDK-Source'

  s.xcconfig = { 'FRAMEWORK_SEARCH_PATHS' => '"${PODS_ROOT}/HockeySDK-Source/Vendor"' }

end
