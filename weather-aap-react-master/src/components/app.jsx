import React from "react";
import { ReactComponent as Logo } from "../images/sun.svg";
import "../App.css";
import WeatherContainer from './WeatherContainer';

function App() {
  return (
    <div className="App">
      <h1>Weather</h1>
      <WeatherContainer />
    </div>
  );
}

export default App;
