import React, { Component } from 'react';


class Search extends Component {
  state = {
    searchText: ''
  }

  onSearchChange = e => {
    this.setState({
      searchText: e.target.value
    });
  }

  handleSubmit = e => {
    e.preventDefault();
    this.props.onSearch(this.query.value);
    e.currentTarget.reset();
  }

  render() {
    return(
      <form className="form-inline ml-auto row justify-content-center search-form" onSubmit={this.handleSubmit}>
        <input type="search"
          className="form-control"
          onChange={this.onSearchChange}
          name="search"
          ref={(input) => this.query = input}
          placeholder="Type city name..." 
        />
        <button className="btn btn-primary" type="submit" id="submit">Search</button>
      </form>
    );
  }
}

export default Search;
