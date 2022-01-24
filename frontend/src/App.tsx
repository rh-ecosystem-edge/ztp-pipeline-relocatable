import React from "react";
import { BrowserRouter, Route, Routes } from "react-router-dom";

import { getService } from "./resources/service";
import WelcomePage from "./WelcomePage";

// import logo from "./logo.svg";
import "./App.css";
import Redirect from "./Redirect";

function App() {
  React.useEffect(() => {
    const doItAsync = async () => {
      const service = await getService({
        name: "router-internal-default",
        namespace: "openshift-ingress",
      }).promise;
      console.log("--- Service: ", service);
    };

    doItAsync();
  }, []);

  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/login/*"
          element={<Redirect to={`http://localhost:4000`} preservePathName />}
        />
        <Route path="*" element={<WelcomePage />} />
      </Routes>
    </BrowserRouter>
  );
  /*
  return (
    <div className="App">
      <header className="App-header">
        <img src={logo} className="App-logo" alt="logo" />
        <p>
          Edit <code>src/App.tsx</code> and save to reload.
        </p>
        <a
          className="App-link"
          href="https://reactjs.org"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn React
        </a>
      </header>
    </div>
  );
  */
}

export default App;
