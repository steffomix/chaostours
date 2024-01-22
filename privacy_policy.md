
## Chaos Tours privacy policy

Chaos Tours prioritizes user privacy and operates without the need for any personalized information. We strongly encourage users to adopt alias names for all interactions, minimizing the risk of revealing real identities.
Additionally, Chaos Tours offers an optional feature allowing users to integrate their data with their device calendar. It is important to exercise caution because sharing your device calendar with others is possible. Therefore, we advise users to be mindful of the information they choose to share, ensuring utmost discretion in their interactions.

# Encryption
The stored data in the app internal database is NOT ENCRYPTED!. It is stored as clear Text information in a common SqLite Database, that can be exported and imported, reopened for inspection and manipulation by any commom SqLite reader or -editor.


You can reduce the calendar entrys to the start time that is required to create a calendar entry and the location id of the app internal database. For example the ID may look like #12345. So that only you as the app owner can search for the ID in his app to lookup its stored data.

## Chaos Tours required permissions:
- Required "FOREGROUND_SERVICE" in order to let the app run as a foreground service in background.
- Required "FOREGROUND_SERVICE_LOCATION", "ACCESS_COARSE_LOCATION", "ACCESS_FINE_LOCATION" to receive location data while running as a foreground service in background.
- Required "FOREGROUND_SERVICE_DATA_SYNC" for communication between the active app and the foreground service running in background

## Chaos Tours optional permissions:
- Optional "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" to keep running the foreground service without time limitations
- Optional "MANAGE_EXTERNAL_STORAGE", "permission.WRITE_EXTERNAL_STORAGE, "permission.READ_EXTERNAL_STORAGE" to import and export its database.
- Optional "INTERNET" to send gps data over an end-to-end encrypted connection to [https://www.openstreetmap.org](https://www.openstreetmap.org) in order receive address informations of the given location. This future is optional and disabled by default.
- Optional 
Chaos Tours requires "permission.READ_CALENDAR", "permission.WRITE_CALENDAR" for an optional future that writes data to the device calendar even when the app is closed and running in the background.
This data can be choosen from a list that includes data like:
  - fine or coarse gps location data as latitude and longitude
  - a clickable link to google maps using gps coordinates of the given location.
  - start time, end time and duration of the time visited at the given location
  - address informations received from [https://www.openstreetmap.org/](https://www.openstreetmap.org) based on gps coordinates of the given location.
  - user defined notices made for the location
  - the location name or address together with a description of the location
  - a list of nearby location names or addresses together with a description of the locations
  - a list of users with optional notices related to the location
  - a list of tasks with optional notices related to the location

Please note that this privacy policy is subject to change over time. We strongly encourage you to proactively monitor it, as the app does not provide notifications to inform users about updates. Stay informed about any modifications to ensure you are aware of the latest terms and conditions governing your use of the application.
- Optional 



If you have any questions or concerns, please contact me at st.brinkmann@gmail.com 
or file an issue here: [https://github.com/steffomix/chaostours/issues](https://github.com/steffomix/chaostours/issues)


Third party service provider:
- [https://github.com/steffomix/chaostours/issues](https://github.com/steffomix/chaostours/issues)
- Device Calendar: Depends on the device calendar provider of the device where the app is installed.
In most cases but in no way granted it is [https://calendar.google.com](https://calendar.google.com)