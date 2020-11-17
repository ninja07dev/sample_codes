import React from 'react';
import DayCard from './DayCard';
import DegreeToggle from './DegreeToggle';
import Search from './Search';

class WeatherContainer extends React.Component {
  state = {
    fullData: [],
    dailyData: [],
    degreeType: "fahrenheit",
    error: null
  }

  fetchData = (query = '') => {
    const APIKEY = 'e893e4f056d90935a146deec80e238c6'
    const weatherURL =
    `http://api.openweathermap.org/data/2.5/forecast?q=${query}&units=imperial&APPID=${APIKEY}`

    fetch(weatherURL)
      .then(response => {
        if (!response.ok) {
          this.setState({fullData: [], dailyData: []})
          throw Error("City not found");
        }
        return response.json();
      })
      .then(data => {
        const dailyData = data.list.filter(reading => reading.dt_txt.includes("18:00:00"))
        this.setState({
          fullData: data.list,
          dailyData: dailyData,
          error: null
        })
      })
      .catch(error => {
        this.setState({ error })
      });
  }

  updateForecastDegree = event => {
    this.setState({ degreeType: event.target.value})
  }

  formatDayCards = () => {
    return this.state.dailyData.map((reading, index) => <DayCard reading={reading} degreeType={this.state.degreeType} key={index} />)
  }

  render() {
    const error = this.state.error
    return (
      <div className="container">
        {error ? <p className="temp">{error.message}</p> : null}

        <Search onSearch={this.fetchData} />
        <DegreeToggle degreeType={this.state.degreeType} updateForecastDegree={this.updateForecastDegree} />
        <div className="row justify-content-center">
          {this.formatDayCards()}
        </div>
      </div>
    )
  }
}

export default WeatherContainer;
