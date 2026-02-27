import { StrictMode, Component } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import { AppWithProviders } from './App.jsx'

class ErrorBoundary extends Component {
  constructor(props) { super(props); this.state = { error: null }; }
  static getDerivedStateFromError(e) { return { error: e }; }
  render() {
    if (this.state.error) {
      return (
        <div style={{background:'#000',color:'#f87171',minHeight:'100vh',padding:'2rem',fontFamily:'monospace',whiteSpace:'pre-wrap'}}>
          <h1 style={{color:'#fff',marginBottom:'1rem'}}>⚠️ Error en MetaCasa</h1>
          <b>{this.state.error.message}</b>
          {'\n\n'}
          {this.state.error.stack}
        </div>
      );
    }
    return this.props.children;
  }
}

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <ErrorBoundary>
      <AppWithProviders />
    </ErrorBoundary>
  </StrictMode>,
)
