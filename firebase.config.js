import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';


const firebaseConfig = {
  apiKey: "AIzaSyCqC_0SJe8fnSyZGS-QGN92Ee7hAvHAC48",
  authDomain: "snapagram-ac74f.firebaseapp.com",
  projectId: "snapagram-ac74f",
  storageBucket: "snapagram-ac74f.firebasestorage.app",
  messagingSenderId: "418723985397",
  appId: "1:418723985397:web:4505fbd46991c2211652bc"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

export default app; 