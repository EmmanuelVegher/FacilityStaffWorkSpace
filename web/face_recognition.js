// NOTE: In your HTML, replace the deprecated meta tag:
//   <meta name="apple-mobile-web-app-capable" content="yes">
// with the updated version:
//   <meta name="mobile-web-app-capable" content="yes">

// Load face-api.js models from local directories
async function loadModels() {
  try {
    console.log("Loading face-api.js models...");
    await faceapi.nets.tinyFaceDetector.loadFromUri('./models/tiny_face_detector');
    console.log("tinyFaceDetector model loaded");
    await faceapi.nets.faceLandmark68Net.loadFromUri('./models/face_landmark_68');
    console.log("faceLandmark68Net model loaded");
    await faceapi.nets.faceRecognitionNet.loadFromUri('./models/face_recognition');
    console.log("faceRecognitionNet model loaded");
    await faceapi.nets.ssdMobilenetv1.loadFromUri('./models/ssd_mobilenetv1');
    console.log("ssdMobilenetv1 model loaded");

    console.log("Face-api.js models loaded successfully");
  } catch (error) {
    console.error("Error loading face-api.js models:", error);
  }
}

loadModels();

async function captureDescriptorFromVideo(videoElementId) {
  console.log("captureDescriptorFromVideo called for element:", videoElementId);
  const video = document.getElementById(videoElementId);
  if (!video) {
    console.error("Video element not found:", videoElementId);
    return null;
  }
  // Wait until the video has loaded data.
  if (video.readyState < 2) {
    await new Promise(resolve => {
      video.onloadeddata = resolve;
    });
  }
  if (!video.srcObject) {
    console.error("Video element has no srcObject. Camera stream may not be active.");
    return null;
  }

  try {
    console.log("Attempting face detection using SSD Mobilenet v1...");
    const detection = await faceapi
      .detectSingleFace(video, new faceapi.SsdMobilenetv1Options({ minConfidence: 0.5 }))
      .withFaceLandmarks()
      .withFaceDescriptor();

    if (!detection) {
      console.warn("No face detected in video element (SSD Mobilenet v1)");
      return null;
    }

    // Convert the raw descriptor to a Float32Array (ensuring consistency)
    // We will now pass the descriptor as is and let Dart handle conversion.
    const descriptor = detection.descriptor; // No conversion here in JS anymore.
    console.log("captureDescriptorFromVideo: Face descriptor (raw from face-api):", Array.from(descriptor)); // Log raw descriptor
    console.log("captureDescriptorFromVideo: Descriptor Type (raw from face-api):", descriptor.constructor.name);
    return descriptor;
  } catch (error) {
    console.error("Error during face detection (SSD Mobilenet v1):", error);
    return null;
  }
}

function _convertJsDescriptor(descriptor) {
  try {
    if (!descriptor) {
      console.error("Descriptor is null or undefined");
      return new Float32Array(); // Return an empty Float32Array if descriptor is null
    }
    // If already a Float32Array, return it as is.
    if (descriptor instanceof Float32Array) {
      return descriptor;
    }
    // If descriptor is a plain array, convert it to Float32Array.
    if (Array.isArray(descriptor)) {
      return new Float32Array(descriptor);
    }

    // Fallback: if it's something else, try to convert it to Float32Array directly.
    // This assumes it's an iterable of numbers or convertible to numbers.
    try {
       return new Float32Array(descriptor);
    } catch (conversionError) {
        console.error("Fallback conversion to Float32Array failed:", conversionError);
        return new Float32Array(); // Return empty array on fallback failure.
    }
  } catch (error) {
    console.error("Error converting descriptor:", error);
    return new Float32Array(); // Return an empty Float32Array on error
  }
}


function compareDescriptors(descriptor1, descriptor2, threshold) {
  console.log("compareDescriptors: descriptor1 (live):", descriptor1 ? descriptor1.toString() : 'null');
  console.log("compareDescriptors: descriptor2 (training):", descriptor2 ? descriptor2.toString() : 'null');

  if (!descriptor1 || !descriptor2) {
    console.error("One or both descriptors are null. Cannot compare.");
    return false;
  }

  if (!(descriptor1 instanceof Float32Array)) {
    console.error("compareDescriptors: descriptor1 is not a Float32Array! Type:", descriptor1.constructor.name);
    return false;
  }
  if (!(descriptor2 instanceof Float32Array)) {
    console.error("compareDescriptors: descriptor2 is not a Float32Array! Type:", descriptor2.constructor.name);
    return false;
  }

  if (descriptor1.length !== descriptor2.length) {
    console.error("compareDescriptors: Descriptor length mismatch. descriptor1 length =", descriptor1.length, "descriptor2 length =", descriptor2.length);
    return false;
  }
  if (descriptor1.length !== 128) {
    console.error("compareDescriptors: descriptor1 length is not 128! Length:", descriptor1.length);
    return false;
  }
  if (descriptor2.length !== 128) {
    console.error("compareDescriptors: descriptor2 length is not 128! Length:", descriptor2.length);
    return false;
  }

  const distance = faceapi.euclideanDistance(descriptor1, descriptor2);
  console.log("compareDescriptors: Euclidean distance:", distance);
  return distance <= threshold;
}

async function compareFaceFromVideo(videoElementId, trainingDescriptor, threshold) {
  const liveDescriptor = await captureDescriptorFromVideo(videoElementId);
  if (!liveDescriptor) {
    console.log("compareFaceFromVideo: liveDescriptor is null (No face detected). Returning null.");
    return null; // Indicate no face detected
  }
  if (!trainingDescriptor) {
    console.error("compareFaceFromVideo: trainingDescriptor is null!");
    return false; // Cannot compare without training data
  }
  // Convert trainingDescriptor to a Float32Array if it's not already.
  const jsTrainingDescriptor = trainingDescriptor instanceof Float32Array
    ? trainingDescriptor
    : new Float32Array(trainingDescriptor);
  if (jsTrainingDescriptor.length !== 128) {
    console.error("compareFaceFromVideo: trainingDescriptor length is not 128 after conversion. Length:", jsTrainingDescriptor.length);
    return false;
  }

  const isMatch = compareDescriptors(liveDescriptor, jsTrainingDescriptor, threshold);
  console.log("compareFaceFromVideo: isMatch:", isMatch);
  return isMatch;
}

window.captureDescriptorFromVideo = captureDescriptorFromVideo;
window.compareFaceFromVideo = compareFaceFromVideo;