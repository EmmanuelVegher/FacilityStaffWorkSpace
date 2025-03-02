// face_recognition.js

// Load face-api.js models from local directories (adjust paths as needed)
async function loadModels() {
  await faceapi.nets.tinyFaceDetector.loadFromUri('./models/tiny_face_detector');
  await faceapi.nets.faceLandmark68Net.loadFromUri('./models/face_landmark_68');
  await faceapi.nets.faceRecognitionNet.loadFromUri('./models/face_recognition');
  console.log("Face-api.js models loaded successfully");
}

// Capture face descriptor from a video element by its ID.
// Waits for the video to be ready and then runs detection.
async function captureDescriptorFromVideo(videoElementId) {
  const video = document.getElementById(videoElementId);
  if (!video) {
    console.error("Video element not found:", videoElementId);
    return null;
  }
  // Wait for the video to have loaded data.
  if (video.readyState < 2) {
    await new Promise((resolve) => {
      video.onloadeddata = resolve;
    });
  }
  const detection = await faceapi
    .detectSingleFace(video, new faceapi.TinyFaceDetectorOptions())
    .withFaceLandmarks()
    .withFaceDescriptor();
  if (!detection) {
    console.error("No face detected in video element");
    return null;
  }
  return detection.descriptor;
}

// Compare two face descriptors using Euclidean distance.
function compareDescriptors(descriptor1, descriptor2, threshold) {
  if (!descriptor1 || !descriptor2) {
    console.error("Descriptors are null");
    return false;
  }
  const distance = faceapi.euclideanDistance(descriptor1, descriptor2);
  return distance < threshold;
}

// Capture a live descriptor from a video element and compare it with a training descriptor.
async function compareFaceFromVideo(videoElementId, trainingDescriptor, threshold) {
  const liveDescriptor = await captureDescriptorFromVideo(videoElementId);
  return compareDescriptors(liveDescriptor, trainingDescriptor, threshold);
}

// Expose functions to Dart via the global window object.
window.loadModels = loadModels;
window.captureDescriptorFromVideo = captureDescriptorFromVideo;
window.compareDescriptors = compareDescriptors;
window.compareFaceFromVideo = compareFaceFromVideo;
