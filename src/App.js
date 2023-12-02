import React from 'react';
import './App.scss';
import './fontawesome.js';

import Background from './Components/Background/Background.jsx';
import LogoBanner from './Components/LogoBanner/LogoBanner.jsx';
import TechStack from './Components/TechStack/TechStack.jsx';
import Portfolio from './Components/Portfolio/Portfolio.jsx';
import Footer from './Components/Footer/Footer.jsx';

function App() {
  return (
    <div className="App">
      <Background/>
      <LogoBanner/>
      <TechStack/>
      <Portfolio/>
      <Footer/>
    </div>
  );
}

export default App;