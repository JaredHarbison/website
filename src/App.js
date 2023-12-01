import React from 'react';
import './App.scss';
import './fontawesome.js';

import Background from './Components/Background/Background.jsx';
import LogoBanner from './Components/LogoBanner/LogoBanner.jsx';

function App() {
  return (
    <div className="App">
      <Background/>
      <LogoBanner/>
    </div>
  );
}

export default App;