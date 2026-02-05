'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "6aef2e4790b19fc99efc45b35e2c3176",
"assets/AssetManifest.bin.json": "97243f6fea5126df7de022ec2b63e11f",
"assets/AssetManifest.json": "1da050666b549102b99540f567e5c180",
"assets/assets/icons/add.png": "a70f87588404026fb1b7043b832dd7ec",
"assets/assets/icons/address.png": "5210a76e3907094815eff395980f3ad1",
"assets/assets/icons/add_to_list.png": "038ac41336300a525ea2ed3f696bad95",
"assets/assets/icons/admin.png": "810c20dffdd0cbbae82dbee196252d92",
"assets/assets/icons/admin_minus.png": "5d17a439567e7c938653e9ab8b267ca2",
"assets/assets/icons/arrow.png": "1b2bac33c918dd7ed1a2881e605a170a",
"assets/assets/icons/back.png": "f3cd83154ed2e365a5c6ff50abd9a89e",
"assets/assets/icons/check.png": "a7a9390568ba2a3d60d1d35509fe5e33",
"assets/assets/icons/circle_delete.png": "d0d0388120d04e9c703fcbc9dd8e9839",
"assets/assets/icons/close.png": "3f6a761ff30c99d73311b0e1bd2cef57",
"assets/assets/icons/comment.png": "5cc22566aae9d2e5f8de58d0ac4786de",
"assets/assets/icons/copy.png": "80b225aff881dffc4827d6b3c8828efc",
"assets/assets/icons/date.png": "1c8941ca701f8084e66c60a5c5d05843",
"assets/assets/icons/delete.png": "fc3979ee8eb8ccdbf4452e3d28ddeadd",
"assets/assets/icons/delivery_date.png": "b4d287a599e34249cd3cbb9b0c46d0b2",
"assets/assets/icons/edit.png": "a639a379660517e91f5191fe3b28bb0b",
"assets/assets/icons/exit.png": "313996cc84a552e78b468b7c2a775276",
"assets/assets/icons/filter.png": "0e146ae9a90b1f127efb88780178b98e",
"assets/assets/icons/for_me.png": "e3e9d87747448c8027964891abf9fa5c",
"assets/assets/icons/for_user.png": "b78956c5d7f9cbd2fcfc12678c101caa",
"assets/assets/icons/group.png": "fd2804c9839d9a9db7a18f67696d1c59",
"assets/assets/icons/important.png": "f95e1ea15c0d9bfbaeeba09012fb4199",
"assets/assets/icons/list.png": "503f9e5d8d7ba58e09c03201eb091492",
"assets/assets/icons/more.png": "77a5e70bc4d28b5acf541962b428a65c",
"assets/assets/icons/notifications.png": "2cdcd592b4c96cfc9056150897dae243",
"assets/assets/icons/notification_fill.png": "3ceb93eb5b4b2aed971b7a884a369e0c",
"assets/assets/icons/participants.png": "05d58be8c52f237359eca57343ed847f",
"assets/assets/icons/paste.png": "bd3fb5ccbaa2c197c68b26adfddf29e9",
"assets/assets/icons/radio_button.png": "e90e0a6b75ab87ef25faf8f94fcea0d8",
"assets/assets/icons/radio_button_confirm.png": "a6f3858fe080249fb46ad08e1a57dd85",
"assets/assets/icons/radio_button_unconfirm.png": "2007d003140afcd089b91fce8a6422a2",
"assets/assets/icons/remind.png": "a332bdc056e587cebde549434e9fae90",
"assets/assets/icons/search.png": "e16b4d20d8f73408ce07265daebcc737",
"assets/assets/icons/star.png": "1c52319f3a9f4590d7591302ff53683a",
"assets/assets/icons/star_filled.png": "106e3ba665531154ff53f82b4d653d22",
"assets/assets/icons/star_outline.png": "0c6d075bdd132bd929983e982a73013a",
"assets/assets/icons/tasks.png": "afcf410a016f4f875f99c87683a383aa",
"assets/assets/icons/team.png": "6fb4bdc75dba201bd31f82738014f077",
"assets/assets/icons/user.png": "b78956c5d7f9cbd2fcfc12678c101caa",
"assets/assets/images/app_icon.png": "c35f25c1a5e776317904b382f17903ff",
"assets/assets/images/background_login_image.png": "6fc7cd45bdd0c56880850973169329c9",
"assets/assets/images/background_register_image.png": "9d82917857573c30175a44680091d09c",
"assets/assets/images/moydodyrof_logo.jpg": "f5d414b69839e4a1834b060f935e2dad",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "d6dc0f7d6c111051114c13bc9132797d",
"assets/NOTICES": "65408ddb5d39eb303008e62ec6429d12",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "1f113b8447cd2d59457767d7ce9b793f",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "75df92d4831ea59669aaa9bdd7cb0650",
"/": "75df92d4831ea59669aaa9bdd7cb0650",
"main.dart.js": "e1eebc33e05a0be784b647463f168dc7",
"manifest.json": "832ac070f68df9201b7161e58d7f9176",
"site.tar.gz": "2a5b9f4f011115a0ee4053e6a284235f",
"task_point_web.zip": "df40a8ad9c9583244e12e35d36ba9094",
"version.json": "47c6e3f38c3e73d2cd048eddf55f5010"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
