<!-- Function to handle file input and display results -->
<!-- Extract this to a bundle or components later -->

var aggData = null;

function processData(rawText){
  console.log("validation run");
  let outsec = document.getElementById('validation-output');

  //Check validity and get list of problems
  let isValid = micca.Validator.validateFile(rawText);
  let problems = micca.Marple.reportProblems(rawText);

  outP = outsec.appendChild( document.createElement("p") );

  outP.innerHTML = "Processing Done";
  outP.innerHTML = `Input file is: ${isValid ? "Valid" : "Invalid"}`;

  if(!isValid){
    outP = outsec.appendChild( document.createElement("pre"));
    outP.innerHTML = JSON.stringify(problems, null, 2);
  }else{
    console.log('doing aggregation');
    aggregationStep(rawText);
    console.log('aggregation done');
  }
  console.log("validation element added");
}

function aggregationStep(rawText){
  console.log("aggregation run");
  let outsec = document.getElementById('aggregation-output');

  // Aggregate data
  aggData = micca.Aeta.digestFile(rawText);

  // Stuff aggregated data into output section
  let outP = outsec.appendChild( document.createElement("p") );
  outP.innerHTML = "Aggregation Done. Data:";

  outP = outsec.appendChild( document.createElement("pre"));
  outP.innerHTML = aggData;

  let confirmButton = document.getElementById('confirm-upload');
  confirmButton.disabled = false;
}

function transmitAggregate(data){
  console.log('transmit aggregate data');
  
  // Disable button to discourage multiple clicks
  let confirmButton = document.getElementById('confirm-upload');
  confirmButton.disabled = true;

  if(data === null){
    console.log('data was null');
    return;
  }

  // Create formData and post it to the endpoint.
  let formData = new FormData();
  let blob = new Blob([data], {type: 'text/csv'});
  formData.append('file', blob, 'aggData.csv');

  var xhr = new XMLHttpRequest();
  xhr.onload = transferComplete;
  xhr.onerror = transferFailed;

  xhr.open('POST', '/upload');
  xhr.send(formData);
}

function transferComplete(evt){
  console.log('Upload complete.');
  let uploadOutput = document.getElementById('upload-output');
  let outP = uploadOutput.appendChild( document.createElement("p") );
  outP.innerHTML = "Upload Done";
}

function transferFailed(evt){
  console.log('Upload FAILED!.');
  let uploadOutput = document.getElementById('upload-output');
  let outP = uploadOutput.appendChild( document.createElement("p") );
  outP.innerHTML = "Upload failed.";

}

function resetValidateAggregate(){
  aggData = null;
  let validateOutput = document.getElementById('validation-output');
  let aggregateOutput = document.getElementById('aggregation-output');
  let uploadOutput = document.getElementById('upload-output');
  let confirmButton = document.getElementById('confirm-upload');

  while(validateOutput.firstChild){ validateOutput.removeChild(validateOutput.firstChild); }
  while(aggregateOutput.firstChild){ aggregateOutput.removeChild(aggregateOutput.firstChild); }
  while(uploadOutput.firstChild){ uploadOutput.removeChild(uploadOutput.firstChild); }

  confirmButton.disabled = true;
}

function onChangeHandler(files){
  console.log("file changed");
  resetValidateAggregate();

  // Read file and update DOM
  let file = files[0];
  try{
    let reader = new FileReader();
    // Define what action to take upon loading input file
    reader.onload = function(e) { processData(reader.result); }
    // Do the read
    reader.readAsText(file);        
  }
  catch(err){ console.log(err); }
}
