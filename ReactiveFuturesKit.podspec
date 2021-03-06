Pod::Spec.new do |s|
  s.name         = "ReactiveFuturesKit"
  # Version goes here and will be used to access the git tag later on, once we have a first release.
  s.version      = "1.1.0"
  s.summary      = "A Swift implementation of Futures built on top of ReactiveSwift"
  s.homepage     = "http://omsignal.com"
  s.author       = "OMsignal"

  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/OMsignal/ReactiveFuturesKit.git", :tag => "v#{s.version}" }
  # Directory glob for all Swift files
  s.source_files  = 'ReactiveFuturesKit/ReactiveFuturesKit/*.{swift}'
  
  s.dependency 'ReactiveSwift', '1.1.3'

  s.pod_target_xcconfig = {"OTHER_SWIFT_FLAGS[config=Release]" => "-suppress-warnings" }
end