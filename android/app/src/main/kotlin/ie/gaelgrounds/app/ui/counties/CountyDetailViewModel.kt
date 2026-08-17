package ie.gaelgrounds.app.ui.counties

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import ie.gaelgrounds.app.data.service.CountyService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class CountyDetailUiState(
    val isLoading: Boolean = true,
    val detail: CountyService.CountyDetail? = null,
)

/** Mirrors ios/GaelGrounds/Views/Counties/CountyDetailView.swift. */
class CountyDetailViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(CountyDetailUiState())
    val uiState: StateFlow<CountyDetailUiState> = _uiState.asStateFlow()

    fun load(countyId: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val detail = CountyService.fetchDetail(countyId)
                _uiState.value = _uiState.value.copy(detail = detail, isLoading = false)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false)
            }
        }
    }
}
