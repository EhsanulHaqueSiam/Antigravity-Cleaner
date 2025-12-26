import { useState } from 'react'
import { Layout } from './components/Layout'
import { Dashboard } from './components/Dashboard'
import { Cleaner } from './components/Cleaner'
import { Tools } from './components/Tools'
import { Backup } from './components/Backup'

function App() {
    const [tab, setTab] = useState('dashboard')

    return (
        <Layout currentTab={tab} onTabChange={setTab}>
            {tab === 'dashboard' && <Dashboard />}
            {tab === 'cleaner' && <Cleaner />}
            {tab === 'network' && <Tools />}
            {tab === 'backup' && <Backup />}
        </Layout>
    )
}

export default App
