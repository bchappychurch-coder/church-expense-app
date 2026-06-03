importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBtbIxm4vqj0g8dH7uHHx6Co5_xLdok-jA",
  authDomain: "church-expense-app.firebaseapp.com",
  projectId: "church-expense-app",
  storageBucket: "church-expense-app.firebasestorage.app",
  messagingSenderId: "602448353479",
  appId: "1:602448353479:web:72c0b4edf45c25540286e2"
});

const messaging = firebase.messaging();
