Pod::Spec.new do |s|
  s.name             = 'core_ads'
  s.version          = '0.0.1'
  s.summary          = 'Reusable Flutter ads package with native templates.'
  s.description      = 'Reusable Flutter ads package with native templates.'
  s.homepage         = 'https://github.com/quanganhdev9s/core_ads'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'core_ads' => 'core_ads@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'core_ads/Sources/core_ads/**/*.{swift,h,m}'
  s.resource_bundles = {
    'core_ads' => ['core_ads/Sources/core_ads/Resources/*']
  }
  s.dependency 'Flutter'
  s.dependency 'Google-Mobile-Ads-SDK', '~> 13.3.0'
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.0'
  s.static_framework = true
end
