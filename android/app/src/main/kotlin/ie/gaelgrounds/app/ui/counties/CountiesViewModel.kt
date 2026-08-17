package ie.gaelgrounds.app.ui.counties

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.model.County
import ie.gaelgrounds.app.data.model.Province
import ie.gaelgrounds.app.data.service.CountyService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class CountiesUiState(
    val isLoading: Boolean = true,
    val counties: List<County> = emptyList(),
) {
    val byProvince: Map<Province, List<County>>
        get() = counties.groupBy { it.province }
}

/**
 * Simplified port of ios/GaelGrounds/Views/Counties/CountiesView.swift --
 * every county is grouped strictly by its `province` column; the iOS
 * "Others" bucket for a handful of overseas GAA board names isn't ported.
 */
class CountiesViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(CountiesUiState())
    val uiState: StateFlow<CountiesUiState> = _uiState.asStateFlow()

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val counties = CountyService.fetchAll()
                _uiState.value = _uiState.value.copy(counties = counties, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }
}
