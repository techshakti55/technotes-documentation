try { rs.status(); } catch (e) {
  if(e.code !== 94 && e.codeName !== "NotYetInitialized") throw e;
  const result=rs.initiate({_id:"rs0",members:[{_id:0,host:"mongodb:27017"}]});
  if(result.ok !== 1) throw new Error("Replica initialization failed");
}
const deadline=Date.now()+90000;
while(!db.hello().isWritablePrimary){
  if(Date.now()>deadline) throw new Error("Test Mongo primary timeout");
  sleep(1000);
}
print("Isolated test replica ready");
