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

import 'package:chaostours/channel/channel_alias.dart';
import 'package:chaostours/channel/channel_task.dart';
import 'package:chaostours/channel/channel_user.dart';
import 'package:chaostours/gps.dart';

class TrackPointData {
  GPS? gps;
  List<GPS> gpsPoints = [];
  List<GPS> gpsSmoothPoints = [];
  List<GPS> gpsCalcPoints = [];
  GPS? gpsLastStatusChange;
  GPS? gpsLastStatusStanding;
  GPS? gpsLastStatusMoving;

  Duration get duration =>
      gpsLastStatusChange?.time.difference(DateTime.now()).abs() ??
      Duration.zero;

  int distanceTreshold = 0; // meter
  Duration durationTreshold = Duration.zero;

  String address = '';
  String fullAddress = '';

  List<ChannelAlias> aliasList = [];
  List<ChannelUser> userList = [];
  List<ChannelTask> taskList = [];

  String notes = '';
}
