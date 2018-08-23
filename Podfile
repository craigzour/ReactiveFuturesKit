platform :ios, '10.0'
use_frameworks!

install! 'cocoapods', :clean => true, :deduplicate_targets => false

workspace 'ReactiveFuturesKit.xcworkspace'

target 'ReactiveFuturesKit' do

    project 'ReactiveFuturesKit/ReactiveFuturesKit.xcodeproj'

    # All ReactiveFuturesKit dependencies have to be added to the podspec
    podspec :name => 'ReactiveFuturesKit'

    target 'ReactiveFuturesKitTests' do
        inherit! :search_paths

        pod 'Nimble', '7.1.3'
    end

end
