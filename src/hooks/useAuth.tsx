import React, { createContext, useContext, useEffect, useState } from 'react';
import { User } from 'firebase/auth';
import { auth } from '../../firebase.config';
// import { onAuthStateChanged } from 'firebase/auth';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
  signInWithGoogle: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // TODO: Enable when Firebase is fully configured
    // const unsubscribe = onAuthStateChanged(auth, (user) => {
    //   setUser(user);
    //   setLoading(false);
    // });
    // return () => unsubscribe();
    
    // Temporary: Set loading to false after a short delay
    setTimeout(() => setLoading(false), 1000);
  }, []);

  const signIn = async (email: string, password: string) => {
    try {
      // TODO: Implement Firebase signInWithEmailAndPassword
      // const result = await signInWithEmailAndPassword(auth, email, password);
      // setUser(result.user);
      console.log('Sign in with:', { email, password });
      
      // Simulate user sign in
      setUser({ email, uid: 'temp-uid' } as User);
    } catch (error) {
      console.error('Sign in error:', error);
      throw error;
    }
  };

  const signUp = async (email: string, password: string) => {
    try {
      // TODO: Implement Firebase createUserWithEmailAndPassword
      // const result = await createUserWithEmailAndPassword(auth, email, password);
      // setUser(result.user);
      
      // TODO: Create user profile in Firestore
      // await createUserProfile(result.user);
      
      console.log('Sign up with:', { email, password });
      
      // Simulate user sign up
      setUser({ email, uid: 'temp-uid' } as User);
    } catch (error) {
      console.error('Sign up error:', error);
      throw error;
    }
  };

  const signOut = async () => {
    try {
      // TODO: Implement Firebase signOut
      // await firebaseSignOut(auth);
      setUser(null);
      console.log('User signed out');
    } catch (error) {
      console.error('Sign out error:', error);
      throw error;
    }
  };

  const signInWithGoogle = async () => {
    try {
      // TODO: Implement Google Sign-In
      console.log('Google Sign-In');
      
      // Simulate Google sign in
      setUser({ email: 'google@example.com', uid: 'google-uid' } as User);
    } catch (error) {
      console.error('Google sign in error:', error);
      throw error;
    }
  };

  const value = {
    user,
    loading,
    signIn,
    signUp,
    signOut,
    signInWithGoogle,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
} 