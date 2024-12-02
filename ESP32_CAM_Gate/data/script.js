var deg = 0;
function capturePhoto() {
  var xhr = new XMLHttpRequest();
  xhr.open('GET', "/capture", true);
  xhr.send();
}
function rotatePhoto() {
  var img = document.getElementById("photo");
  deg += 90;
  if(isOdd(deg/90)){ document.getElementById("container").className = "vert"; }
  else{ document.getElementById("container").className = "hori"; }
  img.style.transform = "rotate(" + deg + "deg)";
}
function isOdd(n) { return Math.abs(n % 2) == 1; }