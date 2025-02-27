console.log("Cron job started!");

function taskA() {
    console.log("A: Checking Death Registry...");
}

function taskB() {
    console.log("B: Distributing Assets...");
}


const task = process.argv[2];

if (task === "checkDeath") {
    taskA();
} else if (task === "distributeAssets") {
    taskB();
} else {
    console.log("Failed");
}
