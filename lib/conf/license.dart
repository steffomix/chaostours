import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget widgetChaosToursLicense = Column(
  children: [
    Text('Copyright ${DateTime.now().year} Stefan Brinkmann'),
    const Text(''),
    const Text(
        '''Licensed under the Apache License, Version 2.0 (the "License");
you may not use this app except in compliance with the License.
You may obtain a copy of the License at\n'''),
    FilledButton(
      child: const Text('http://www.apache.org/licenses/LICENSE-2.0'),
      onPressed: () {
        launchUrl(Uri(
            scheme: 'http',
            host: 'www.apache.org',
            pathSegments: ['licenses', 'LICENSE-2.0']));
      },
    ),
    const Text(
        '''\nUnless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.'''),
    const Text(''),
  ],
);

String chaosToursLicense = '''Chaos Tours License

Copyright ${DateTime.now().year} Stefan Brinkmann

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this app except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License.
''';

String osmLicense = '''OpenStreetMap License

OpenStreetMap® is open data, licensed under the Open Data Commons Open Database License (ODbL) by the OpenStreetMap Foundation (OSMF).

You are free to copy, distribute, transmit and adapt our data, as long as you credit OpenStreetMap and its contributors.
If you alter or build upon our data, you may distribute the result only under the same licence.
The full legal code explains your rights and responsibilities.''';
