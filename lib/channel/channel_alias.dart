/*
Copyright 2023 Stefan Brinkmann <st.brinkmann@gmail.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:chaostours/channel/channel_asset.dart';
import 'package:chaostours/model/model_alias.dart';
import 'package:chaostours/shared/shared_trackpoint_alias.dart';

class ChannelAlias implements ChannelAsset {
  final int distance;
  @override
  final ModelAlias model;
  @override
  final SharedTrackpointAlias shared;

  ChannelAlias(
      {required this.model, required this.shared, required this.distance});
}
