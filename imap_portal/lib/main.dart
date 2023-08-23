import 'dart:async';
import 'dart:io';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AnimatedSplashScreen(
          splashIconSize: 150,
          backgroundColor: Colors.white,
          splash: Image.asset("assets/images/imap_logo.png"),
          duration: 3000,
          nextScreen: const WebView()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebView extends StatefulWidget {
  const WebView({Key? key}) : super(key: key);

  @override
  State<WebView> createState() => _WebViewState();
}

class _WebViewState extends State<WebView> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> _onBack() async {
    bool goBack = false;
    var value = await webViewController?.canGoBack();
    if (value!) {
      webViewController?.goBack();
      return false;
    } else {
      await showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text("Confirmation"),
                content: Text("Do you want to exit the app ?"),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        setState(() {
                          goBack = false;
                        });
                      },
                      child: Text("No")),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        setState(() {
                          goBack = true;
                        });
                      },
                      child: Text("Yes"))
                ],
              ));
      if (goBack) Navigator.pop(context);
      return goBack;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBack,
      child: Scaffold(
          body: SafeArea(
              child: Column(children: <Widget>[
        Expanded(
          child: Stack(
            children: [
              InAppWebView(
                key: webViewKey,
                initialUrlRequest:
                    URLRequest(url: Uri.parse("https://portal.imap.edu.ng")),
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                  return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED);
                },
                initialOptions: options,
                pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    this.url = url.toString();
                    urlController.text = this.url;
                  });
                },
                androidOnPermissionRequest:
                    (controller, origin, resources) async {
                  return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.GRANT);
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  var uri = navigationAction.request.url!;

                  if (![
                    "http",
                    "https",
                    "file",
                    "chrome",
                    "data",
                    "javascript",
                    "about"
                  ].contains(uri.scheme)) {
                    // and cancel the request
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, url) async {
                  pullToRefreshController.endRefreshing();
                  setState(() {
                    this.url = url.toString();
                    urlController.text = this.url;
                  });
                },
                onLoadError: (controller, url, code, message) async {
                  pullToRefreshController.endRefreshing();
                  var tRexHtml = await controller.getTRexRunnerHtml();
                  var tRexCss = await controller.getTRexRunnerCss();

                  controller.loadData(data: """
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0,maximum-scale=1.0, user-scalable=no">
<style>$tRexCss</style>
</head>
<body>
$tRexHtml
<p>
Unable to connect to IMAP Portal.<br/>Please ensure that you have internet connection then restart the app.
</p>
</body>
</html>
""");
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController.endRefreshing();
                  }
                  setState(() {
                    this.progress = progress / 100;
                    urlController.text = this.url;
                  });
                },
                onUpdateVisitedHistory: (controller, url, androidIsReload) {
                  setState(() {
                    this.url = url.toString();
                    urlController.text = this.url;
                  });
                },
              ),
              progress < 1.0
                  ? LinearProgressIndicator(value: progress)
                  : Container(),
            ],
          ),
        ),
      ]))),
    );
  }
}

class ErrorPage extends StatefulWidget {
  const ErrorPage({Key? key}) : super(key: key);

  @override
  State<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Column(
        children: [
          const Text("Pls ensure that you have internet connection."),
          IconButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const WebView()));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.refresh_rounded))
        ],
      )),
    );
  }
}

/* class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  Color? appColor = const Color.fromARGB(255, 66, 110, 255);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            const SizedBox(
              height: 10,
            ),
            SizedBox(
                height: 160,
                width: 150,
                child: Image.asset("assets/images/imap_logo.png")),
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Officer Login",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: Color.fromARGB(255, 66, 110, 255)),
                )
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            const Text("Happy to see you again!",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w300)),
            const SizedBox(
              height: 20,
            ),
            Column(
              children: [
                const Text("Username"),
                const SizedBox(
                  height: 5,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Color.fromARGB(255, 66, 110, 255),
                        size: 18,
                      ),
                      const SizedBox(
                        width: 40,
                      ),
                      SizedBox(
                          width: MediaQuery.of(context).size.width * 0.73,
                          child: TextFormField(
                              decoration: const InputDecoration.collapsed(
                                  hintText: "username")))
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            Column(
              children: [
                const Text("Password"),
                const SizedBox(
                  height: 5,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Color.fromARGB(255, 66, 110, 255),
                        size: 18,
                      ),
                      const SizedBox(
                        width: 40,
                      ),
                      SizedBox(
                          width: MediaQuery.of(context).size.width * 0.73,
                          child: TextFormField(
                              decoration: const InputDecoration.collapsed(
                                  hintText: "password")))
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(
              height: 15,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Row(
                children: [
                  Theme(
                    child: Checkbox(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        value: false,
                        onChanged: (value) {}),
                    data: ThemeData(unselectedWidgetColor: appColor),
                  ),
                  const Text("Keep me signed in"),
                  Expanded(child: Container()),
                  const Text("Forgot password?")
                ],
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Container(
              width: double.maxFinite,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: appColor, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: const Center(
                  child: Text("LOGIN",
                      style: TextStyle(color: Colors.white, fontSize: 16))),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.46,
                    decoration: BoxDecoration(
                        color: appColor,
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_rounded, color: Colors.white),
                        const SizedBox(
                          width: 5,
                        ),
                        const Text("Student",
                            style: TextStyle(color: Colors.white))
                      ],
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.46,
                    decoration: BoxDecoration(
                        color: Color.fromARGB(255, 116, 216, 112),
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        const Text("Applicant",
                            style: TextStyle(color: Colors.white))
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("New Applicant? "),
                Text("Apply Here", style: TextStyle(color: appColor))
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            Text("Other Fees Payments(Tender, Contract, Refund etc)",
                style: TextStyle(color: appColor)),
            SizedBox(
              height: 20,
            ),
            Container(
              decoration: BoxDecoration(),
              child: Center(
                child: Text("Copyright c 2021 All rights reserved."),
              ),
            )
          ]),
        ),
      ),
    );
  }
}
 */