The `firebaseAdmin.js` file initializes the Firebase application using the **service account key credentials**, ensuring secure authentication and access to Firestore.  

The `firestoreOperations.js` file handles **reading, writing, updating, and deleting data** in Firestore. It is designed to **simulate a government death registry and grant of probate system**, enabling structured data management for probate applications.

Run the following command:  

```bash
node firestoreOperations
```  

This command automatically invokes `firebaseAdmin.js` to initialize the Firebase credentials before executing Firestore operations.