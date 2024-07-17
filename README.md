## tang_network

The util of HTTP Networking with the capabilities:

- Get
- Post
- Upload
- Download
- `abstract configuration` supported

### Installation

```yaml
dependencies:
  tang_network: ^0.0.1
```

### Usage

#### Setup

- Implements the configurations for your project,
```dart
/// Configuration.
class MainConfigNetworkHttp implements NetworkHttpConfig { ... }
/// Base.
class MainConfigNetworkHttpBase implements NetworkHttpBase { ... }
/// Keys.
class MainConfigNetworkHttpKeys implements NetworkHttpKeys { ... }
/// Codes.
class MainConfigNetworkHttpCodes implements NetworkHttpCodes { ... }
/// Getters.
class MainConfigNetworkHttpGetters implements NetworkHttpGetters { ... }
/// Callbacks.
class MainConfigNetworkHttpCallbacks implements NetworkHttpCallbacks { ... }
```

- Invoke the `setup()` method before the root page displaying,
```dart
await NetworkHttp.shared.setup(config: MainConfigNetworkHttp());
```

- Invoke the `setupDeviceInfo()` method after user has granted the permission of `Device Info`, if you do not invoke this method, the `Device Info` will be passively initialized when the `NetworkHttp.shared.request()` method is called for the first time.
```dart
onPrivacyPolicyConfirmed: () async {
  await NetworkHttp.shared.setupDeviceInfo();
}
```

- Create your own API class and call the `NetworkHttp` APIs to send the requests,
```dart
final response = await NetworkHttp.shared.request('/api-service/module/method',
  {
    'param1': 1,
    'param2': '2',
  },
  method: NetworkMethodType.post,
).then((resp) => NetworkRespModel.fromJson(resp));
return response;
```