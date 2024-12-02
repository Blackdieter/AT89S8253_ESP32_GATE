window.addEventListener('load', getValues); 
function getValues(){ 
  var xhr = new XMLHttpRequest(); 
  xhr.onreadystatechange = function() { 
    if (this.readyState == 4 && this.status == 200) { 
      var myObj = JSON.parse(this.responseText); 
      console.log(myObj); 
      document.getElementById("textFieldValue").innerHTML = myObj.textValue; 
      document.getElementById("numberFieldValue").innerHTML = myObj.numberValue; 
    } 
  };  
  xhr.open("GET", "/values", true); 
  xhr.send(); 
} 
var deg = 0;
function capturePhoto(){
  var xhr = new XMLHttpRequest();
  xhr.open('GET', "/capture", true);
  // xhr.onload = function(){
  //   if(xhr.status === 200){
  //     // Update the image source to the new photo
  //     document.getElementById('photo').src = "/saved-photo?" + new Date().getTime();
  //   }
  // }
  xhr.send();
}
function rotatePhoto(){
  var img = document.getElementById("photo");
  deg += 90;
  if(isOdd(deg/90)){ document.getElementById("container").className = "vert"; }
  else{document.getElementById("container").className = "hori";}
  img.style.transform = "rotate(" + deg + "deg)";
}
function isOdd(n){return Math.abs(n % 2)==1;}

// Create a new EventSource object
var eventSource = new EventSource('/events');

// Define the event handler for incoming messages
eventSource.addEventListener('photo', function(event) {
    // Update the image source to the new photo
    document.getElementById('password').innerHTML = 'Message: ' + event.data;
    document.getElementById('photo').src = "/saved-photo?" + new Date().getTime();
});

// Optional: Define additional event handlers for open and error events
eventSource.onopen = function() {
    console.log('Connection to server opened.');
};

eventSource.onerror = function() {
    console.log('Error occurred while receiving updates.');
};
