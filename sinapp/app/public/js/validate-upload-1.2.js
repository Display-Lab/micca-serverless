// Function to handle file input and display results
// TODO: Extract this to a bundle or components later
// version 1.1

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

  clearElementChildren('aggregation-output');
}

function transferComplete(evt){
  console.log('Upload complete.');
  let uploadOutput = document.getElementById('upload-output');
  uploadOutput.appendChild( document.createElement("hr") );

  let outP = uploadOutput.appendChild( document.createElement("p") );
  outP.classList.add("text-success");
  outP.innerHTML = "Upload Done";

  let outPre = uploadOutput.appendChild( document.createElement("pre") );
  outPre.innerHTML = this.response;
}

function transferFailed(evt){
  console.log('Upload FAILED!.');
  let uploadOutput = document.getElementById('upload-output');
  uploadOutput.appendChild( document.createElement("hr") );

  let outP = uploadOutput.appendChild( document.createElement("p") );
  outP.innerHTML = "Upload failed.";
  outP.classList.add("text-error");

  let outPre = uploadOutput.appendChild( document.createElement("pre") );
  outPre.innerHTML = this.response;
}

function clearElementChildren(eleId){
  let ele = document.getElementById(eleId);
  while(ele.firstChild){ ele.removeChild(ele.firstChild); }
}

function resetAllOutputs(){
  aggData = null;
  clearElementChildren('aggregation-output');
  clearElementChildren('validation-output');
  clearElementChildren('upload-output');

  let confirmButton = document.getElementById('confirm-upload');
  confirmButton.disabled = true;
}

function onChangeHandler(input){
  console.log('file changed');
  let file = input.files[0];
  let statusElement = document.getElementById('input-status');
  let now = new Date();

  // Provide some user facing change
  statusElement.innerHTML = 'processing ' + file.name + ' started: ' + now.toTimeString();
  resetAllOutputs();

  // Read file and update DOM
  try{
    let reader = new FileReader();
    // Define what action to take upon loading input file
    reader.onload = function(e) { processData(reader.result); }
    // Do the read.  Waiting for DOM to update.
    setTimeout(function(){reader.readAsText(file)}, 1500);
  }
  catch(err){ console.log(err); }

  // Reset the input so same file can be selected twice.
  input.value = null;
  return false;
}
