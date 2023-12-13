import React from 'react';
import './Background.scss';
import fog1 from '../../Assets/Images/fog1.png'
import fog2 from '../../Assets/Images/fog2.png'
import fog3 from '../../Assets/Images/fog3.png'
import fog4 from '../../Assets/Images/fog4.png'
import fog5 from '../../Assets/Images/fog5.png'

function Background() {
  return (
    <div className="Background">
      <div class="bg">
        <div class="fog">
          <img src={fog1} style={{"--i": 1}} />
          <img src={fog2} style={{"--i": 2}} />
          <img src={fog3} style={{"--i": 3}} />
          <img src={fog4} style={{"--i": 4}} />
          <img src={fog5} style={{"--i": 5}} />
          <img src={fog1} style={{"--i": 10}} />
          <img src={fog2} style={{"--i": 9}} />
          <img src={fog3} style={{"--i": 8}} />
          <img src={fog4} style={{"--i": 7}} />
          <img src={fog5} style={{"--i": 6}} />
        </div>
      </div>
      <div class="stars"></div>
      <div class="twinkling"></div>
      <div className="background-rom-and-moon"></div>
      <div className="top-gradiated-background-layer"></div>
      <div className="background-rom-cutout"></div>
      <div className="middle-gradiated-background-layer"></div>
      <div className="background-upsidedown-rom-cutout"></div>
      <div className="bottom-gradiated-background-layer"></div>
    </div>
  );
}

export default Background;