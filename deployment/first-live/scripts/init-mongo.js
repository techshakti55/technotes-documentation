// Fresh production database only. Idempotent replica/app-user initialization.
try { rs.status(); } catch (e) {
    if (e.code !== 94 && e.codeName !== "NotYetInitialized") throw e;
    const result = rs.initiate({_id:"rs0",members:[{_id:0,host:"mongodb:27017"}]});
    if (result.ok !== 1) throw new Error("Replica initialization failed");
}
const deadline=Date.now()+90000;
while (!db.hello().isWritablePrimary) {
    if (Date.now()>deadline) throw new Error("Mongo primary readiness timeout");
    sleep(1000);
}
const notes=db.getSiblingDB("technotes_notes");
if (!notes.getUser("technotes_notes")) {
    notes.createUser({user:"technotes_notes",pwd:process.env.MONGO_APP_PASSWORD,
        roles:[{role:"readWrite",db:"technotes_notes"}]});
}
print("Production replica set and Notes user ready");
