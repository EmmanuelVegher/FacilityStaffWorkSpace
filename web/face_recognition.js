// NOTE: In your HTML, replace the deprecated meta tag:
//   <meta name="apple-mobile-web-app-capable" content="yes">
// with the updated version:
//   <meta name="mobile-web-app-capable" content="yes">

// Load face-api.js models from local directories
async function loadModels() {
  try {
    console.log("Loading face-api.js models...");

    // Load models in parallel for better performance
    const modelPromises = [
      faceapi.nets.tinyFaceDetector.loadFromUri('./models/tiny_face_detector'),
      faceapi.nets.mtcnn.loadFromUri('./models/mtcnn'),
      faceapi.nets.faceLandmark68Net.loadFromUri('./models/face_landmark_68'),
      faceapi.nets.faceRecognitionNet.loadFromUri('./models/face_recognition'),
      faceapi.nets.ssdMobilenetv1.loadFromUri('./models/ssd_mobilenetv1')
    ];

    await Promise.all(modelPromises);

    console.log("All face-api.js models loaded successfully");

    // Set up global reference for models loaded status
    window.faceModelsLoaded = true;

  } catch (error) {
    console.error("Error loading face-api.js models:", error);
    window.faceModelsLoaded = false;
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

  // Check if models are loaded
  if (!window.faceModelsLoaded) {
    console.error("Face detection models not loaded yet");
    return null;
  }

  const detectionOptions = [
    // Try MTCNN with different settings
    new faceapi.MtcnnOptions({ minFaceSize: 80 }),
    new faceapi.MtcnnOptions({ minFaceSize: 100 }),
    new faceapi.MtcnnOptions({ minFaceSize: 120 }),
    // Try SSD Mobilenet with different settings
    new faceapi.SsdMobilenetv1Options({ minConfidence: 0.5, maxResults: 1 }),
    new faceapi.SsdMobilenetv1Options({ minConfidence: 0.3, maxResults: 1 }),
    new faceapi.SsdMobilenetv1Options({ minConfidence: 0.2, maxResults: 1 }),
    // Try Tiny Face Detector
    new faceapi.TinyFaceDetectorOptions({ inputSize: 320, scoreThreshold: 0.5 }),
    new faceapi.TinyFaceDetectorOptions({ inputSize: 320, scoreThreshold: 0.3 }),
  ];

  for (let i = 0; i < detectionOptions.length; i++) {
    try {
      const option = detectionOptions[i];
      console.log(`Attempting face detection with option ${i + 1}/${detectionOptions.length}...`);

      let detection;

      if (option instanceof faceapi.MtcnnOptions) {
        detection = await faceapi
          .detectSingleFace(video, option)
          .withFaceLandmarks()
          .withFaceDescriptor();
      } else if (option instanceof faceapi.SsdMobilenetv1Options) {
        detection = await faceapi
          .detectSingleFace(video, option)
          .withFaceLandmarks()
          .withFaceDescriptor();
      } else if (option instanceof faceapi.TinyFaceDetectorOptions) {
        detection = await faceapi
          .detectSingleFace(video, option)
          .withFaceLandmarks()
          .withFaceDescriptor();
      }

      if (detection) {
        const descriptor = detection.descriptor;
        if (descriptor && descriptor.length === 128) {
          console.log(`Face detected successfully with option ${i + 1}, descriptor length:`, descriptor.length);
          return descriptor;
        } else {
          console.warn(`Invalid descriptor length with option ${i + 1}:`, descriptor?.length);
        }
      }
    } catch (error) {
      console.warn(`Face detection failed with option ${i + 1}:`, error.message);
    }
  }

  console.warn("No face detected with any detection method");
  return null;
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
  console.log("compareFaceFromVideo: Starting comparison with threshold:", threshold);

  const liveDescriptor = await captureDescriptorFromVideo(videoElementId);
  if (!liveDescriptor) {
    console.log("compareFaceFromVideo: liveDescriptor is null (No face detected). Returning null.");
    return null; // Indicate no face detected
  }

  if (!trainingDescriptor) {
    console.error("compareFaceFromVideo: trainingDescriptor is null!");
    return false; // Cannot compare without training data
  }

  // Ensure trainingDescriptor is a Float32Array
  let jsTrainingDescriptor;
  try {
    if (trainingDescriptor instanceof Float32Array) {
      jsTrainingDescriptor = trainingDescriptor;
    } else if (Array.isArray(trainingDescriptor)) {
      jsTrainingDescriptor = new Float32Array(trainingDescriptor);
    } else {
      console.error("compareFaceFromVideo: trainingDescriptor is not a valid type");
      return false;
    }

    if (jsTrainingDescriptor.length !== 128) {
      console.error("compareFaceFromVideo: trainingDescriptor length is not 128. Length:", jsTrainingDescriptor.length);
      return false;
    }
  } catch (error) {
    console.error("compareFaceFromVideo: Error converting trainingDescriptor:", error);
    return false;
  }

  const isMatch = compareDescriptors(liveDescriptor, jsTrainingDescriptor, threshold);
  console.log("compareFaceFromVideo: isMatch:", isMatch, "distance threshold:", threshold);
  return isMatch;
}

// Auto face verification system
let autoVerificationInterval = null;
let isAutoVerificationRunning = false;

async function startAutoVerification(videoElementId, trainingDescriptor, threshold, callback) {
  if (isAutoVerificationRunning) {
    console.log("Auto verification already running");
    return;
  }

  console.log("Starting auto face verification...");
  isAutoVerificationRunning = true;

  autoVerificationInterval = setInterval(async () => {
    try {
      const result = await compareFaceFromVideo(videoElementId, trainingDescriptor, threshold);
      if (result === true) {
        console.log("Auto verification successful!");
        stopAutoVerification();
        if (callback) callback(true);
      }
    } catch (error) {
      console.error("Error in auto verification:", error);
    }
  }, 1000); // Check every second
}

function stopAutoVerification() {
  if (autoVerificationInterval) {
    clearInterval(autoVerificationInterval);
    autoVerificationInterval = null;
  }
  isAutoVerificationRunning = false;
  console.log("Auto verification stopped");
}

window.captureDescriptorFromVideo = captureDescriptorFromVideo;
window.compareFaceFromVideo = compareFaceFromVideo;
window.startAutoVerification = startAutoVerification;
window.stopAutoVerification = stopAutoVerification;